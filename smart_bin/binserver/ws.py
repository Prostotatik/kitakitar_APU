"""WebSocket transport adapter. Thin: it translates frames into runtime calls and
registers the socket so the runtime can push back. All lifecycle logic is in the
runtime; nothing here mutates a session.

Wire protocol is frozen to match the deployed firmware:
  in  (text JSON): { device_id, label, confidence }   confidence is a percent
  out (text JSON): { event, ... }                      qr_generated | qr_scanned | ...
"""

from __future__ import annotations

import json

from aiohttp import WSMsgType, web

from .runtime import SessionRuntime


async def ws_handler(request: web.Request) -> web.WebSocketResponse:
    runtime: SessionRuntime = request.app["runtime"]
    ws = web.WebSocketResponse()
    await ws.prepare(request)

    device_id: str | None = None
    try:
        async for msg in ws:
            if msg.type != WSMsgType.TEXT:
                if msg.type == WSMsgType.ERROR:
                    break
                continue
            try:
                data = json.loads(msg.data)
            except (ValueError, TypeError):
                await ws.send_json({"event": "error", "message": "invalid JSON"})
                continue

            device_id = str(data.get("device_id", "unknown"))
            label = str(data.get("label", "unknown"))
            try:
                confidence = float(data.get("confidence", 0.0))
            except (ValueError, TypeError):
                confidence = 0.0

            runtime.registry.register(device_id, ws)
            print(f"  [WS] device={device_id} label={label} conf={confidence:.1f}%")
            await runtime.on_detection(device_id, label, confidence)
    finally:
        if device_id is not None:
            runtime.registry.unregister(device_id, ws)
    return ws
