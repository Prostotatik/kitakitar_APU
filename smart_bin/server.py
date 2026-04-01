"""
server.py — Smart Recycle Bin Server
======================================
Runs TWO servers simultaneously:

  ws://0.0.0.0:8765   — WebSocket for JSON metadata  { device_id, label, confidence }
  http://0.0.0.0:8766 — HTTP POST  /upload            raw JPEG photo

Both save to the same SQLite database (recycle_data.db).
Photos saved to captured_images/<label>_<timestamp>.jpg

For each upload with label paper or can, optionally creates a Firestore /qr_codes
document (same shape as center_web createIntakeQr) when Firebase is configured.

Install:
    pip install -r requirements.txt

Run:
    python server.py

Env (optional, for QR creation):
    FIREBASE_SERVICE_ACCOUNT or GOOGLE_APPLICATION_CREDENTIALS — path to service account JSON
    SMART_BIN_CENTER_ID — Firestore centers/{id} for this bin
"""

from __future__ import annotations

import asyncio
import base64
import io
import json
import os
import sqlite3
from datetime import datetime, timezone
from typing import Any

import aiohttp.web
import segno
import websockets

try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    from google.cloud.firestore import SERVER_TIMESTAMP
except ImportError:  # pragma: no cover
    firebase_admin = None  # type: ignore
    credentials = None  # type: ignore
    firestore = None  # type: ignore
    SERVER_TIMESTAMP = None  # type: ignore

DB_PATH   = "recycle_data.db"
IMAGE_DIR = "captured_images"
WS_HOST   = "0.0.0.0"
WS_PORT   = 8765
HTTP_HOST = "0.0.0.0"
HTTP_PORT = 8766

KITAKITAR_QR_PREFIX = "KITAKITAR_QR:"

# Hard‑wired Firebase center / credentials for this smart bin
SMART_BIN_CENTER_ID = "gwTyIuDCyDQtMdJIWbfoDYIVj0l1"
FIREBASE_SERVICE_ACCOUNT = (
    r"E:\Projects\KitaKitar_APU\smart_bin\kitakitar-firebase-adminsdk-fbsvc-4a3db70058.json"
)

# Model label -> (Firestore material type, weight kg) — mirrors center_web createIntakeQr
_LABEL_TO_TYPE_WEIGHT: dict[str, tuple[str, float]] = {
    "paper": ("paper", 0.005),
    "can": ("aluminum", 0.015),
}

_firestore_db: Any = None
_firebase_qr_enabled = False


def init_firebase() -> None:
    """Initialize Firebase Admin if credentials and center id are set."""
    global _firestore_db, _firebase_qr_enabled

    if firebase_admin is None or credentials is None or firestore is None:
        print("[Firebase] firebase-admin not installed; QR creation disabled.")
        return

    cred_path = FIREBASE_SERVICE_ACCOUNT
    center_id = SMART_BIN_CENTER_ID

    if not cred_path or not os.path.isfile(cred_path):
        print("[Firebase] No service account JSON; QR creation disabled.")
        return
    if not center_id:
        print("[Firebase] SMART_BIN_CENTER_ID not set; QR creation disabled.")
        return

    try:
        cred = credentials.Certificate(cred_path)
        try:
            firebase_admin.get_app()
        except ValueError:
            firebase_admin.initialize_app(cred)
        _firestore_db = firestore.client()
        _firebase_qr_enabled = True
        print("[Firebase] Admin SDK ready — QR codes will use center", center_id)
    except Exception as exc:  # pragma: no cover
        print(f"[Firebase] Init failed: {exc}")


def _find_material_row(db: Any, center_id: str, material_type: str) -> dict[str, Any] | None:
    """First materials subdocument with matching type (same as center lookup)."""
    col = (
        db.collection("centers")
        .document(center_id)
        .collection("materials")
        .where("type", "==", material_type)
        .limit(1)
    )
    for snap in col.stream():
        return snap.to_dict() or {}
    return None


def create_intake_qr_sync(detection_label: str) -> dict[str, Any] | None:
    """
    Create /qr_codes doc like CenterFirestoreService.createIntakeQr.
    Returns { id, payload, png_base64 } or None if skipped / disabled.
    """
    if not _firebase_qr_enabled or _firestore_db is None:
        return None

    spec = _LABEL_TO_TYPE_WEIGHT.get(detection_label)
    if spec is None:
        return None

    firestore_type, weight_kg = spec
    center_id = SMART_BIN_CENTER_ID

    mat = _find_material_row(_firestore_db, center_id, firestore_type)
    price_per_kg = float(mat.get("pricePerKg") or 0) if mat else 0.0
    # Same as createIntakeQr: (mat?.isFree ?? true) || pricePerKg <= 0 → here price always from mat or 0
    is_free = (price_per_kg <= 0)

    draft_materials = [
        {
            "type": firestore_type,
            "weight": weight_kg,
            "pricePerKg": price_per_kg,
            "isFree": is_free,
        }
    ]
    total_weight = weight_kg

    _, doc_ref = _firestore_db.collection("qr_codes").add(
        {
            "centerId": center_id,
            "transactionDraft": {
                "materials": draft_materials,
                "totalWeight": total_weight,
            },
            "used": False,
            "createdAt": SERVER_TIMESTAMP,
        }
    )
    qr_id = doc_ref.id
    payload = f"{KITAKITAR_QR_PREFIX}{qr_id}"

    qr = segno.make(payload)
    buf = io.BytesIO()
    qr.save(buf, kind="png", scale=8)
    png_b64 = base64.b64encode(buf.getvalue()).decode("ascii")

    return {
        "id": qr_id,
        "payload": payload,
        "png_base64": png_b64,
    }


# ════════════════════════════════════════════════════════════════
# Database
# ════════════════════════════════════════════════════════════════
def init_db() -> None:
    os.makedirs(IMAGE_DIR, exist_ok=True)
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS detections (
                id          INTEGER PRIMARY KEY AUTOINCREMENT,
                device_id   TEXT    NOT NULL,
                label       TEXT    NOT NULL,
                confidence  REAL    NOT NULL,
                image_path  TEXT    NOT NULL,
                timestamp   TEXT    NOT NULL
            )
        """)
    print(f"[DB]  Ready  →  {DB_PATH}")


def save_detection(device_id: str, label: str,
                   confidence: float, image_path: str) -> int:
    ts = datetime.now(timezone.utc).isoformat()
    with sqlite3.connect(DB_PATH) as conn:
        cur = conn.execute(
            "INSERT INTO detections (device_id, label, confidence, image_path, timestamp) "
            "VALUES (?, ?, ?, ?, ?)",
            (device_id, label, confidence, image_path, ts),
        )
    return cur.lastrowid


# ════════════════════════════════════════════════════════════════
# WebSocket server  —  receives JSON metadata only
# ════════════════════════════════════════════════════════════════
async def ws_handler(websocket) -> None:
    addr = websocket.remote_address
    print(f"[WS]  ESP32 connected  —  {addr}")

    try:
        async for message in websocket:
            if not isinstance(message, str):
                # We no longer expect binary on this channel
                await websocket.send(json.dumps({"error": "text only on WS"}))
                continue

            try:
                data = json.loads(message)
            except json.JSONDecodeError:
                print(f"  [WARN] Bad JSON: {message!r}")
                await websocket.send(json.dumps({"error": "invalid JSON"}))
                continue

            label      = data.get("label",      "unknown")
            confidence = float(data.get("confidence", 0.0))
            device_id  = data.get("device_id",  "unknown")

            print(f"  [WS META] device={device_id}  label={label}  conf={confidence:.1f}%")
            await websocket.send(json.dumps({"status": "meta_received"}))

    except websockets.exceptions.ConnectionClosedOK:
        pass
    except websockets.exceptions.ConnectionClosedError as exc:
        print(f"  [WARN] WS connection error from {addr}: {exc}")
    finally:
        print(f"[WS]  ESP32 disconnected  —  {addr}")


async def run_ws_server() -> None:
    async with websockets.serve(ws_handler, WS_HOST, WS_PORT):
        print(f"[WS]  Listening on  ws://{WS_HOST}:{WS_PORT}")
        await asyncio.Future()   # run forever


# ════════════════════════════════════════════════════════════════
# HTTP server  —  receives JPEG photo via POST /upload
#
# ESP32 sends:
#   POST http://<host>:8766/upload?label=can&device_id=esp32-cam-01&confidence=95.3
#   Content-Type: image/jpeg
#   Body: <raw JPEG bytes>
# ════════════════════════════════════════════════════════════════
async def http_upload_handler(request: aiohttp.web.Request) -> aiohttp.web.Response:
    # Read query-string params sent by the ESP32
    label      = request.rel_url.query.get("label",      "unknown")
    device_id  = request.rel_url.query.get("device_id",  "unknown")
    confidence = float(request.rel_url.query.get("confidence", 0.0))

    # Read raw JPEG body
    jpeg_bytes = await request.read()

    if not jpeg_bytes:
        return aiohttp.web.Response(status=400, text="Empty body")

    # Save image
    ts_str   = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S_%f")
    filename = f"{label}_{ts_str}.jpg"
    img_path = os.path.join(IMAGE_DIR, filename)

    with open(img_path, "wb") as f:
        f.write(jpeg_bytes)

    # Save DB record
    row_id = save_detection(device_id, label, confidence, img_path)

    print(
        f"  [HTTP] id={row_id}  device={device_id}  "
        f"label={label}  conf={confidence:.1f}%  "
        f"size={len(jpeg_bytes):,} B  →  {filename}"
    )

    response_body: dict[str, Any] = {
        "status": "ok",
        "id": row_id,
        "filename": filename,
    }

    async def _try_qr() -> dict[str, Any] | None:
        try:
            return await asyncio.to_thread(create_intake_qr_sync, label)
        except Exception as exc:
            print(f"  [Firebase] QR create failed: {exc}")
            return None

    qr_info = await _try_qr()
    if qr_info:
        response_body["qr"] = qr_info
        print(f"  [Firebase] QR created  id={qr_info['id']}")

    return aiohttp.web.json_response(response_body)


async def run_http_server() -> None:
    app = aiohttp.web.Application(client_max_size=5 * 1024 * 1024)  # 5 MB max
    app.router.add_post("/upload", http_upload_handler)

    runner = aiohttp.web.AppRunner(app)
    await runner.setup()
    site = aiohttp.web.TCPSite(runner, HTTP_HOST, HTTP_PORT)
    await site.start()
    print(f"[HTTP] Listening on  http://{HTTP_HOST}:{HTTP_PORT}/upload")


# ════════════════════════════════════════════════════════════════
# Query helpers  (import in analytics / chatbot scripts)
# ════════════════════════════════════════════════════════════════
def get_latest() -> dict:
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "SELECT * FROM detections ORDER BY timestamp DESC LIMIT 1"
        ).fetchone()
    return dict(row) if row else {"error": "no detections yet"}


def get_recent(limit: int = 10) -> list[dict]:
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT * FROM detections ORDER BY timestamp DESC LIMIT ?", (limit,)
        ).fetchall()
    return [dict(r) for r in rows]


def get_stats() -> dict:
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute("""
            SELECT
                COUNT(*)                      AS total_detections,
                SUM(label = 'paper')          AS paper_count,
                SUM(label = 'can')            AS can_count,
                ROUND(AVG(confidence), 2)     AS avg_confidence,
                MIN(confidence)               AS min_confidence,
                MAX(confidence)               AS max_confidence,
                MIN(timestamp)                AS first_detection,
                MAX(timestamp)                AS last_detection
            FROM detections
        """).fetchone()
    return dict(row)


def get_by_label(label: str) -> list[dict]:
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT * FROM detections WHERE label = ? ORDER BY timestamp DESC",
            (label,),
        ).fetchall()
    return [dict(r) for r in rows]


# ════════════════════════════════════════════════════════════════
# Entry point — run both servers concurrently
# ════════════════════════════════════════════════════════════════
async def main() -> None:
    init_db()
    init_firebase()
    await asyncio.gather(
        run_ws_server(),
        run_http_server(),
    )


if __name__ == "__main__":
    print("=== Smart Recycle Bin Server ===")
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n[!] Server stopped.")
