"""HTTP transport adapter — the evidence path. Saves the JPEG and one detection row,
returns a small ack. It does NOT feed a session or mint a QR (that is the WS frame's
job). The firmware only reads the response status code, so the body is just a receipt.

  POST /upload?label=&device_id=&confidence=   body: raw JPEG
"""

from __future__ import annotations

import os

from aiohttp import web

from . import evidence
from .config import Config


async def upload_handler(request: web.Request) -> web.Response:
    cfg: Config = request.app["config"]
    query = request.rel_url.query
    label = query.get("label", "unknown")
    device_id = query.get("device_id", "unknown")
    try:
        confidence = float(query.get("confidence", 0.0))
    except (ValueError, TypeError):
        confidence = 0.0

    jpeg = await request.read()
    if not jpeg:
        return web.Response(status=400, text="Empty body")

    path = await _run_blocking(request, evidence.save_photo, cfg.image_dir, label, jpeg)
    row_id = await _run_blocking(
        request, evidence.record_detection, cfg.db_path, device_id, label, confidence, path
    )
    print(
        f"  [HTTP] id={row_id} device={device_id} label={label} "
        f"conf={confidence:.1f}% size={len(jpeg):,}B -> {os.path.basename(path)}"
    )
    return web.json_response(
        {"status": "ok", "id": row_id, "filename": os.path.basename(path)}
    )


async def _run_blocking(request, fn, *args):
    run_blocking = request.app.get("run_blocking")
    if run_blocking is not None:
        return await run_blocking(fn, *args)
    import asyncio

    return await asyncio.to_thread(fn, *args)
