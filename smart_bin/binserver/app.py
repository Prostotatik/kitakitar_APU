"""Composition root — wire Config -> ledger -> runtime -> two aiohttp sites.

One aiohttp app serves both routes; two TCP sites expose them on the firmware's two
ports (WS on 8765, HTTP on 8766). The `websockets` library is gone — aiohttp does both.
"""

from __future__ import annotations

import asyncio

from aiohttp import web

from . import evidence
from .config import Config
from .http import upload_handler
from .ledger import InMemoryLedger, MaterialPrice, NullLedger, QrLedger
from .notifier import DeviceRegistry
from .runtime import SessionRuntime
from .ws import ws_handler


def build_ledger(cfg: Config) -> tuple[QrLedger, bool, dict[str, MaterialPrice]]:
    """Returns (ledger, qr_enabled, prices). Firebase problems are loud here, never a
    silent fallback."""
    if cfg.demo_mode:
        print("=" * 60)
        print("  DEMO MODE — in-memory ledger. QR docs are NOT persisted.")
        print("=" * 60)
        ledger = InMemoryLedger()
        return ledger, True, ledger.prices()

    if cfg.center_id and cfg.service_account:
        try:
            from .ledger import FirestoreLedger

            ledger = FirestoreLedger(cfg.center_id, cfg.service_account)
            print(f"[Firebase] Ready — QR codes use center {cfg.center_id}")
            print(f"[Firebase] Cached {len(ledger.prices())} material price(s)")
            return ledger, True, ledger.prices()
        except Exception as exc:
            print("=" * 60)
            print(f"  FIREBASE INIT FAILED: {exc}")
            print("  Falling back to EVIDENCE-ONLY mode — NO QR codes.")
            print("=" * 60)
            return NullLedger(), False, {}

    print("=" * 60)
    print("  EVIDENCE-ONLY MODE — no Firebase configured.")
    print("  Photos + SQLite only. The bin issues NO QR codes / points.")
    print("  Set SMART_BIN_CENTER_ID and FIREBASE_SERVICE_ACCOUNT to enable QR.")
    print("=" * 60)
    return NullLedger(), False, {}


def build_app(runtime: SessionRuntime, cfg: Config) -> web.Application:
    app = web.Application(client_max_size=cfg.upload_max_bytes)
    app["runtime"] = runtime
    app["config"] = cfg
    app.router.add_get("/", ws_handler)
    app.router.add_post("/upload", upload_handler)
    return app


async def run() -> None:
    print("=== Smart Recycle Bin Server ===")
    cfg = Config.from_env()
    evidence.init_storage(cfg.db_path, cfg.image_dir)
    print(f"[DB]  Ready -> {cfg.db_path}")

    ledger, qr_enabled, prices = build_ledger(cfg)
    loop = asyncio.get_running_loop()
    runtime = SessionRuntime(
        ledger=ledger,
        registry=DeviceRegistry(),
        config=cfg,
        prices=prices,
        clock=loop.time,
        call_at=loop.call_at,
        qr_enabled=qr_enabled,
        loop=loop,
    )

    swept = await runtime.sweep()
    if swept:
        print(f"[SWEEP] Removed {swept} stale pending QR doc(s)")

    app = build_app(runtime, cfg)
    runner = web.AppRunner(app)
    await runner.setup()
    ws_site = web.TCPSite(runner, cfg.ws_host, cfg.ws_port)
    http_site = web.TCPSite(runner, cfg.http_host, cfg.http_port)
    await ws_site.start()
    await http_site.start()
    print(f"[WS]   Listening on ws://{cfg.ws_host}:{cfg.ws_port}")
    print(f"[HTTP] Listening on http://{cfg.http_host}:{cfg.http_port}/upload")

    try:
        await asyncio.Event().wait()
    finally:
        await runner.cleanup()
