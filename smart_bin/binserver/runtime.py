"""SessionRuntime — the async shell around the pure IntakeSession core.

All I/O lives here: the device<->session map, qr-id correlation, timers, the ledger and
the device notifier. The shell executes the effect lists the core returns and threads
qr ids (which the core never sees) through publication and redemption.

Concurrency: WS frames and (marshalled) redemption callbacks both land on the event
loop. A per-device lock serialises the shell's own async sections so the one-doc
invariant holds under interleaving — this is the shell guarding its I/O ordering, not
lock discipline leaking into the core.

Timing is injected (`clock`, `call_at`) so the whole shell is drivable by a fake clock
in tests with no real sleeping. Blocking ledger calls go through `run_blocking`
(asyncio.to_thread in prod, inline in tests).
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from typing import Awaitable, Callable

from . import bitmap
from .config import Config
from .ledger import MaterialPrice, QrLedger, Redeemed
from .notifier import DeviceRegistry
from .session import (
    Close,
    DraftMaterial,
    Effect,
    Expire,
    IntakeSession,
    Notify,
    Publish,
    ShowQr,
    should_accept,
)


class TimerHandle:
    def cancel(self) -> None: ...


ClockFn = Callable[[], float]
CallAtFn = Callable[[float, Callable[[], None]], TimerHandle]
RunBlockingFn = Callable[..., Awaitable]


async def _to_thread(fn, *args):
    return await asyncio.to_thread(fn, *args)


@dataclass
class _Grace:
    device_id: str
    void_handle: TimerHandle


class SessionRuntime:
    def __init__(
        self,
        *,
        ledger: QrLedger,
        registry: DeviceRegistry,
        config: Config,
        prices: dict[str, MaterialPrice],
        clock: ClockFn,
        call_at: CallAtFn,
        qr_enabled: bool,
        loop: asyncio.AbstractEventLoop | None = None,
        run_blocking: RunBlockingFn = _to_thread,
    ):
        self._ledger = ledger
        self._registry = registry
        self._cfg = config
        self._prices = prices
        self._clock = clock
        self._call_at = call_at
        self._qr_enabled = qr_enabled
        self._loop = loop
        self._run_blocking = run_blocking

        self._sessions: dict[str, IntakeSession] = {}   # device -> active session
        self._session_qr: dict[str, str] = {}           # device -> its current qr id
        self._qr_device: dict[str, str] = {}            # qr id -> device (active only)
        self._watches: dict[str, object] = {}           # qr id -> Watch
        self._bitmaps: dict[str, list[int]] = {}        # qr id -> OLED bytes
        self._grace: dict[str, _Grace] = {}             # qr id -> grace entry
        self._tick_handle: dict[str, TimerHandle] = {}  # device -> pending tick
        self._last_accept: dict[str, float] = {}        # device -> last accepted time
        self._locks: dict[str, asyncio.Lock] = {}

    @property
    def registry(self) -> DeviceRegistry:
        return self._registry

    # ── inbound: a WS detection (the intake event) ───────────────────────────
    async def on_detection(self, device_id: str, label: str, confidence: float) -> None:
        now = self._clock()
        since = now - self._last_accept.get(device_id, float("-inf"))
        if not should_accept(
            confidence, since, self._cfg.min_confidence, self._cfg.accept_cooldown
        ):
            return

        if not self._qr_enabled:
            self._last_accept[device_id] = now
            return

        material = self._material_for(label)
        if material is None:
            return

        async with self._lock(device_id):
            self._last_accept[device_id] = now
            session = self._sessions.get(device_id)
            if session is None:
                session = self._open_session(device_id, now)
            try:
                await self._run(device_id, session.add(material, now))
            except Redeemed:
                # Redemption won the supersede race. Settle the redeemed QR (the device
                # gets qr_scanned) and re-seed a fresh session with just this item, so
                # the pending drop is never lost.
                await self._settle_active_redeemed(device_id, now)
                session = self._open_session(device_id, now)
                await self._run(device_id, session.add(material, now))
            self._reschedule_tick(device_id)

    # ── inbound: a redemption (marshalled onto the loop by the ledger cb) ─────
    async def on_redeemed(self, qr_id: str) -> None:
        now = self._clock()
        device_id = self._qr_device.get(qr_id)
        if device_id is not None:
            async with self._lock(device_id):
                if self._session_qr.get(device_id) == qr_id:
                    await self._settle_active_redeemed(device_id, now)
            return

        grace = self._grace.pop(qr_id, None)
        if grace is not None:
            grace.void_handle.cancel()
            await self._registry.send(grace.device_id, {"event": "qr_scanned"})
            self._drop_qr(qr_id)

    def on_redeemed_threadsafe(self, qr_id: str) -> None:
        """Callback handed to ledger.watch. Runs on a gRPC background thread; hops onto
        the event loop before touching any shell state."""
        loop = self._loop
        if loop is None:
            return
        loop.call_soon_threadsafe(lambda: asyncio.ensure_future(self.on_redeemed(qr_id)))

    # ── startup sweep ────────────────────────────────────────────────────────
    async def sweep(self) -> int:
        if not self._qr_enabled:
            return 0
        import time

        cutoff = time.time() - self._cfg.grace_tail
        try:
            return await self._run_blocking(self._ledger.sweep_pending, cutoff)
        except Exception as exc:  # pragma: no cover - defensive
            print(f"[SWEEP] failed: {exc}")
            return 0

    # ── effect executor ──────────────────────────────────────────────────────
    async def _run(self, device_id: str, effects: list[Effect]) -> None:
        for eff in effects:
            if isinstance(eff, Publish):
                await self._publish(device_id, eff.draft)
            elif isinstance(eff, ShowQr):
                await self._show_qr(device_id, eff.points, eff.timer_seconds)
            elif isinstance(eff, Notify):
                await self._registry.send(device_id, {"event": eff.kind})
            elif isinstance(eff, Expire):
                self._expire(device_id)
            elif isinstance(eff, Close):
                self._close(device_id)

    async def _publish(self, device_id: str, draft) -> None:
        qr_id = self._session_qr.get(device_id)
        if qr_id is None:
            qr_id = await self._run_blocking(self._ledger.create, draft)
            self._session_qr[device_id] = qr_id
            self._qr_device[qr_id] = device_id
            self._watches[qr_id] = self._ledger.watch(qr_id, self.on_redeemed_threadsafe)
        else:
            # may raise Redeemed -> handled by on_detection
            await self._run_blocking(self._ledger.supersede, qr_id, draft)

    async def _show_qr(self, device_id: str, points: int, timer_seconds: int) -> None:
        qr_id = self._session_qr.get(device_id)
        if qr_id is None:
            return
        bits = self._bitmaps.get(qr_id)
        if bits is None:
            payload = bitmap.make_payload(qr_id, self._cfg.qr_prefix)
            bits = bitmap.qr_bitmap(payload)
            self._bitmaps[qr_id] = bits
        await self._registry.send(
            device_id,
            {
                "event": "qr_generated",
                "qr_id": qr_id,
                "qr_bitmap": bits,
                "points": points,
                "timer_seconds": timer_seconds,
            },
        )

    # ── terminal transitions ─────────────────────────────────────────────────
    def _close(self, device_id: str) -> None:
        """Session done, QR consumed by redemption — drop everything."""
        self._cancel_tick(device_id)
        qr_id = self._session_qr.pop(device_id, None)
        self._sessions.pop(device_id, None)
        if qr_id is not None:
            self._qr_device.pop(qr_id, None)
            self._drop_qr(qr_id)

    def _expire(self, device_id: str) -> None:
        """Display window elapsed — drop the session but keep the QR redeemable through
        the grace tail, then void it."""
        self._cancel_tick(device_id)
        qr_id = self._session_qr.pop(device_id, None)
        self._sessions.pop(device_id, None)
        if qr_id is None:
            return
        self._qr_device.pop(qr_id, None)
        void_at = self._clock() + self._cfg.grace_tail
        handle = self._call_at(
            void_at, lambda: asyncio.ensure_future(self._void(qr_id))
        )
        self._grace[qr_id] = _Grace(device_id, handle)
        # watch stays alive so a grace-time scan still routes (see on_redeemed)

    async def _settle_active_redeemed(self, device_id: str, now: float) -> None:
        session = self._sessions.get(device_id)
        if session is not None:
            await self._run(device_id, session.redeemed(now))

    async def _void(self, qr_id: str) -> None:
        self._grace.pop(qr_id, None)
        try:
            await self._run_blocking(self._ledger.void, qr_id)
        except Exception:
            pass
        self._drop_qr(qr_id)

    # ── helpers ──────────────────────────────────────────────────────────────
    def _open_session(self, device_id: str, now: float) -> IntakeSession:
        session = IntakeSession(device_id, self._cfg.session_deadline, now)
        self._sessions[device_id] = session
        return session

    def _material_for(self, label: str) -> DraftMaterial | None:
        spec = self._cfg.label_to_type_weight.get(label)
        if spec is None:
            return None
        mtype, weight = spec
        price = self._prices.get(mtype, MaterialPrice(0.0, True))
        return DraftMaterial(mtype, weight, price.price_per_kg, price.is_free)

    def _reschedule_tick(self, device_id: str) -> None:
        self._cancel_tick(device_id)
        session = self._sessions.get(device_id)
        if session is None:
            return
        at = session.wake_at()
        if at is None:
            return
        self._tick_handle[device_id] = self._call_at(
            at, lambda: asyncio.ensure_future(self._on_tick(device_id))
        )

    def _cancel_tick(self, device_id: str) -> None:
        handle = self._tick_handle.pop(device_id, None)
        if handle is not None:
            handle.cancel()

    async def _on_tick(self, device_id: str) -> None:
        now = self._clock()
        async with self._lock(device_id):
            session = self._sessions.get(device_id)
            if session is None:
                return
            effects = session.tick(now)
            if effects:
                await self._run(device_id, effects)
            else:
                self._reschedule_tick(device_id)

    def _drop_qr(self, qr_id: str) -> None:
        watch = self._watches.pop(qr_id, None)
        if watch is not None:
            watch.cancel()
        self._bitmaps.pop(qr_id, None)

    def _lock(self, device_id: str) -> asyncio.Lock:
        lock = self._locks.get(device_id)
        if lock is None:
            lock = self._locks[device_id] = asyncio.Lock()
        return lock
