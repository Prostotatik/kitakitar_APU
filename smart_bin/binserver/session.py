"""IntakeSession — the deep module that owns one device's accumulation run.

Pure and synchronous: no asyncio, no sockets, no Firestore, no clock of its own.
Every call takes `now` (a float from the shell's monotonic clock) and returns a list
of effects for the shell to execute. This is the whole point of the design — every
race and timer scenario is a table-driven test with a fake clock (test_session.py),
and there is exactly one place session state can change.

Lifecycle owned here: OPEN accumulation and the deadline. Grace tail, voiding, and
qr-id correlation are the shell's job (runtime.py) — they are inherently about timers
and the ledger, so they live where the I/O is.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum, auto

from . import estimate


# ── Domain values ────────────────────────────────────────────────────────────
@dataclass(frozen=True)
class DraftMaterial:
    type: str
    weight: float
    price_per_kg: float
    is_free: bool


@dataclass(frozen=True)
class Draft:
    materials: tuple[DraftMaterial, ...]
    total_weight: float


# ── Effects (what the shell must do) ─────────────────────────────────────────
@dataclass(frozen=True)
class Publish:
    """Create-or-supersede this session's one QR doc with this draft."""
    draft: Draft


@dataclass(frozen=True)
class ShowQr:
    """Push a QrView to the device. qr id + bitmap are the shell's to attach."""
    points: int
    timer_seconds: int


@dataclass(frozen=True)
class Notify:
    """Send a bare event frame to the device: qr_scanned | timer_expired."""
    kind: str


@dataclass(frozen=True)
class Close:
    """Session is done and its QR consumed — drop it, drop the QR."""


@dataclass(frozen=True)
class Expire:
    """Display window elapsed — drop the session, move its QR to the grace tail."""


Effect = Publish | ShowQr | Notify | Close | Expire


# ── Acceptance gate (pure decision; the shell holds the timestamps) ──────────
def should_accept(
    confidence: float,
    seconds_since_last_accept: float,
    min_confidence: float,
    cooldown: float,
) -> bool:
    """A detection becomes an intake event only above the confidence floor and once
    the per-device cooldown has elapsed. The cooldown (~one servo cycle) collapses the
    re-fire storm without rejecting real throughput."""
    return confidence >= min_confidence and seconds_since_last_accept >= cooldown


class _State(Enum):
    OPEN = auto()
    CLOSED = auto()


class IntakeSession:
    def __init__(self, device_id: str, deadline_seconds: float, now: float):
        self.device_id = device_id
        self._deadline_seconds = deadline_seconds
        self._by_type: dict[str, DraftMaterial] = {}
        self._deadline = now + deadline_seconds
        self._state = _State.OPEN

    # add ---------------------------------------------------------------------
    def add(self, material: DraftMaterial, now: float) -> list[Effect]:
        """Accumulate one accepted item. Items of the same type merge (three sheets of
        paper -> one entry), matching center_web's createIntakeQr draft shape. Resets
        the deadline. Returns Publish (upsert the draft) then ShowQr (points derived
        from the draft, so the OLED promises what redemption pays)."""
        if self._state is _State.CLOSED:
            return []

        prev = self._by_type.get(material.type)
        if prev is None:
            self._by_type[material.type] = material
        else:
            self._by_type[material.type] = DraftMaterial(
                material.type,
                prev.weight + material.weight,
                material.price_per_kg,
                material.is_free,
            )

        self._deadline = now + self._deadline_seconds
        draft = self._draft()
        points = estimate.estimate_points(draft.materials)
        return [Publish(draft), ShowQr(points, int(self._deadline_seconds))]

    # redeemed ----------------------------------------------------------------
    def redeemed(self, now: float) -> list[Effect]:
        """The QR was scanned while still accumulating. Idempotent: a duplicate watch
        fire after close is a no-op."""
        if self._state is _State.CLOSED:
            return []
        self._state = _State.CLOSED
        return [Notify("qr_scanned"), Close()]

    # tick --------------------------------------------------------------------
    def tick(self, now: float) -> list[Effect]:
        """Called by the shell at wake_at(). Past the deadline the display clears and
        the QR enters its grace tail; an early tick is a no-op."""
        if self._state is _State.CLOSED:
            return []
        if now >= self._deadline:
            self._state = _State.CLOSED
            return [Notify("timer_expired"), Expire()]
        return []

    # queries -----------------------------------------------------------------
    def wake_at(self) -> float | None:
        """When the shell should next call tick(): the deadline while OPEN, else None."""
        return self._deadline if self._state is _State.OPEN else None

    @property
    def is_open(self) -> bool:
        return self._state is _State.OPEN

    def _draft(self) -> Draft:
        materials = tuple(self._by_type[t] for t in sorted(self._by_type))
        total = sum(m.weight for m in materials)
        return Draft(materials, total)
