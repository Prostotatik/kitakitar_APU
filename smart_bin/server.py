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
    r"YOUR PATH HERE\kitakitar-smart-bin-firebase-adminsdk-abcde-1234567890.json"
)

# Model label -> (Firestore material type, weight kg) — mirrors center_web createIntakeQr
_LABEL_TO_TYPE_WEIGHT: dict[str, tuple[str, float]] = {
    "paper": ("paper", 0.005),
    "can": ("aluminum", 0.015),
}


# ════════════════════════════════════════════════════════════════
# Accumulator — tracks pending items per device
# ════════════════════════════════════════════════════════════════
class Accumulator:
    """
    Tracks accumulated items per device with a 30-second timer.
    When a new item arrives, points accumulate and timer resets.
    """

    def __init__(self, timeout_seconds: int = 30):
        self.timeout = timeout_seconds
        self._pending: dict[str, dict] = {}  # device_id -> {items, timer_task, qr_id}

    def add_item(self, device_id: str, label: str) -> tuple[int, asyncio.Task | None]:
        """
        Add an item to the accumulator for this device.
        Returns (total_points, timer_task or None if new).
        """
        points = self._get_points_for_label(label)

        if device_id not in self._pending:
            # First item for this device
            self._pending[device_id] = {
                "items": [{"label": label, "points": points}],
                "total_points": points,
                "timer_task": None,
                "qr_id": None,
            }
            return points, None
        else:
            # Accumulate with existing items
            self._pending[device_id]["items"].append({"label": label, "points": points})
            self._pending[device_id]["total_points"] += points
            # Cancel existing timer if any
            if self._pending[device_id]["timer_task"]:
                self._pending[device_id]["timer_task"].cancel()
            return self._pending[device_id]["total_points"], None

    def set_timer_task(self, device_id: str, task: asyncio.Task) -> None:
        """Store the timer task for cancellation on new items."""
        if device_id in self._pending:
            self._pending[device_id]["timer_task"] = task

    def set_qr_id(self, device_id: str, qr_id: str) -> None:
        """Store the current QR ID for Firestore listener."""
        if device_id in self._pending:
            self._pending[device_id]["qr_id"] = qr_id

    def get_qr_id(self, device_id: str) -> str | None:
        """Get the current QR ID for this device."""
        return self._pending.get(device_id, {}).get("qr_id")

    def clear(self, device_id: str) -> None:
        """Clear pending items for this device."""
        if device_id in self._pending:
            if self._pending[device_id]["timer_task"]:
                self._pending[device_id]["timer_task"].cancel()
            del self._pending[device_id]

    def get_total_points(self, device_id: str) -> int:
        """Get total accumulated points for this device."""
        return self._pending.get(device_id, {}).get("total_points", 0)

    def get_items(self, device_id: str) -> list[dict]:
        """Get list of accumulated items for this device."""
        return self._pending.get(device_id, {}).get("items", [])

    def _get_points_for_label(self, label: str) -> int:
        """Get points for a material type."""
        # Points are weight * 100 (see _LABEL_TO_TYPE_WEIGHT)
        spec = _LABEL_TO_TYPE_WEIGHT.get(label)
        if spec:
            # weight_kg * 100 = points (simplified)
            return int(spec[1] * 100)  # 0.005 * 100 = 0.5 -> need better calc
        return 50  # Default fallback


# Global accumulator instance
accumulator = Accumulator(timeout_seconds=30)

_firestore_db: Any = None
_firebase_qr_enabled = False
_qr_watch = None


# ════════════════════════════════════════════════════════════════
# Firestore QR Redemption Listener
# ════════════════════════════════════════════════════════════════
def on_qr_document_snapshot(doc_snapshot, changes, read_time):
    """
    Callback for Firestore on_snapshot.
    Triggered when QR document is modified (e.g., used=true).
    """
    for change in changes:
        if change.type.name == 'MODIFIED':
            doc = change.document
            data = doc.to_dict()

            # Check if QR was just redeemed (used field changed to True)
            if data.get("used") is True:
                qr_id = doc.id
                print(f"[FIRESTORE] QR redeemed: {qr_id}")

                # Find which device this QR belongs to
                device_id = None
                for dev_id, pending in accumulator._pending.items():
                    if pending.get("qr_id") == qr_id:
                        device_id = dev_id
                        break

                if device_id and device_id in _connected_devices:
                    # Notify ESP32 via WebSocket
                    asyncio.create_task(
                        send_event_to_device(_connected_devices[device_id], "qr_scanned")
                    )
                    # Clear accumulator
                    accumulator.clear(device_id)
                    print(f"  [WS] Sent qr_scanned to device={device_id}")


def start_firestore_listener():
    """Start listening for QR redemptions."""
    global _qr_watch

    if not _firebase_qr_enabled or _firestore_db is None:
        print("[FIRESTORE] Listener not started — Firebase not initialized")
        return

    try:
        # Watch the qr_codes collection
        _qr_watch = _firestore_db.collection("qr_codes").on_snapshot(on_qr_document_snapshot)
        print("[FIRESTORE] Started listening for QR redemptions")
    except Exception as exc:
        print(f"[FIRESTORE] Failed to start listener: {exc}")


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


def create_intake_qr_sync(items: list[dict]) -> dict[str, Any] | None:
    """
    Create /qr_codes doc like CenterFirestoreService.createIntakeQr.

    Args:
        items: List of accumulated items, each with 'label' and 'points' keys

    Returns { id, payload, png_base64, qr_bitmap } or None if skipped/disabled.
    """
    if not _firebase_qr_enabled or _firestore_db is None:
        return None

    if not items:
        return None

    center_id = SMART_BIN_CENTER_ID
    draft_materials = []
    total_weight = 0.0

    # Build materials list from all accumulated items
    for item in items:
        label = item.get("label")
        spec = _LABEL_TO_TYPE_WEIGHT.get(label)
        if spec is None:
            continue

        firestore_type, weight_kg = spec
        mat = _find_material_row(_firestore_db, center_id, firestore_type)
        price_per_kg = float(mat.get("pricePerKg") or 0) if mat else 0.0
        is_free = (price_per_kg <= 0)

        draft_materials.append(
            {
                "type": firestore_type,
                "weight": weight_kg,
                "pricePerKg": price_per_kg,
                "isFree": is_free,
            }
        )
        total_weight += weight_kg

    if not draft_materials:
        return None

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

    # Generate bitmap for SSD1306
    qr_bitmap = qr_to_bitmap(qr, size=64)

    return {
        "id": qr_id,
        "payload": payload,
        "png_base64": png_b64,
        "qr_bitmap": qr_bitmap,
    }


# ════════════════════════════════════════════════════════════════
# QR Bitmap Conversion (for SSD1306 OLED)
# ════════════════════════════════════════════════════════════════
def qr_to_bitmap(qr: segno.QRCode, size: int = 64) -> list[int]:
    """
    Convert a QR code to a 1-bit bitmap for SSD1306 OLED.

    Args:
        qr: segno QR code object
        size: Output size in pixels (default 64x64)

    Returns:
        List of bytes (512 bytes for 64x64 = 4096 bits)
    """
    import math

    # Get QR matrix
    matrix = qr.matrix
    qr_size = len(matrix)

    # Scale to desired size
    scale = size // qr_size
    if scale < 1:
        scale = 1

    # Create bitmap buffer (1 bit per pixel)
    # 64x64 pixels = 4096 bits = 512 bytes
    bitmap_size = (size * size + 7) // 8
    bitmap = [0] * bitmap_size

    # Fill bitmap
    for row_idx, row in enumerate(matrix):
        for col_idx, module in enumerate(row):
            if module:  # Dark module (1)
                # Calculate position in scaled output
                for dy in range(scale):
                    for dx in range(scale):
                        y = row_idx * scale + dy
                        x = col_idx * scale + dx
                        if y < size and x < size:
                            # Set bit (MSB first, 8 pixels per byte)
                            bit_index = y * size + x
                            byte_index = bit_index // 8
                            bit_offset = 7 - (bit_index % 8)
                            bitmap[byte_index] |= (1 << bit_offset)

    return bitmap


# ════════════════════════════════════════════════════════════════
# WebSocket Message Helpers
# ════════════════════════════════════════════════════════════════
async def send_qr_to_device(websocket, qr_info: dict, points: int, timer_seconds: int = 30) -> None:
    """Send QR bitmap to ESP32 via WebSocket."""
    if not qr_info:
        return

    message = {
        "event": "qr_generated",
        "qr_id": qr_info["id"],
        "qr_bitmap": qr_info["qr_bitmap"],
        "points": points,
        "timer_seconds": timer_seconds,
    }
    await websocket.send(json.dumps(message))
    print(f"  [WS] Sent QR to device: id={qr_info['id']} points={points}")


async def send_event_to_device(websocket, event: str, message: str = "") -> None:
    """Send a simple event to ESP32."""
    msg = {"event": event}
    if message:
        msg["message"] = message
    await websocket.send(json.dumps(msg))


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

# Track connected devices
_connected_devices: dict[str, websockets.WebSocketServerProtocol] = {}


async def qr_timer_callback(device_id: str, websocket) -> None:
    """Called after 30 seconds of inactivity."""
    try:
        await asyncio.sleep(30)  # 30 second timer

        # Timer expired - notify device
        await send_event_to_device(websocket, "timer_expired")
        print(f"  [TIMER] Expired for device={device_id}")

        # Clear accumulator for this device
        accumulator.clear(device_id)

    except asyncio.CancelledError:
        # Timer was cancelled (new item arrived)
        print(f"  [TIMER] Cancelled for device={device_id}")


async def ws_handler(websocket) -> None:
    addr = websocket.remote_address
    device_id = "unknown"
    print(f"[WS]  ESP32 connected  —  {addr}")

    try:
        async for message in websocket:
            if not isinstance(message, str):
                await websocket.send(json.dumps({"event": "error", "message": "text only on WS"}))
                continue

            try:
                data = json.loads(message)
            except json.JSONDecodeError:
                print(f"  [WARN] Bad JSON: {message!r}")
                await websocket.send(json.dumps({"event": "error", "message": "invalid JSON"}))
                continue

            label = data.get("label", "unknown")
            confidence = float(data.get("confidence", 0.0))
            device_id = data.get("device_id", "unknown")

            # Track connected device
            _connected_devices[device_id] = websocket

            print(f"  [WS META] device={device_id}  label={label}  conf={confidence:.1f}%")

            # Add item to accumulator
            total_points, _ = accumulator.add_item(device_id, label)
            print(f"  [ACCUM] device={device_id}  total_points={total_points}")

            # Get all accumulated items for this device
            accumulated_items = accumulator.get_items(device_id)

            # Create QR in Firestore with ALL accumulated items (runs in thread pool)
            qr_info = await asyncio.to_thread(create_intake_qr_sync, accumulated_items)

            if qr_info:
                # Store QR ID for this device
                accumulator.set_qr_id(device_id, qr_info["id"])

                # Send QR to device
                await send_qr_to_device(websocket, qr_info, total_points)

                # Start/reset timer for this device
                timer_task = asyncio.create_task(
                    qr_timer_callback(device_id, websocket)
                )
                accumulator.set_timer_task(device_id, timer_task)

    except websockets.exceptions.ConnectionClosedOK:
        pass
    except websockets.exceptions.ConnectionClosedError as exc:
        print(f"  [WARN] WS connection error from {addr}: {exc}")
    finally:
        # Clean up
        if device_id in _connected_devices:
            del _connected_devices[device_id]
        accumulator.clear(device_id)
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
    label = request.rel_url.query.get("label", "unknown")
    device_id = request.rel_url.query.get("device_id", "unknown")
    confidence = float(request.rel_url.query.get("confidence", 0.0))

    # Read raw JPEG body
    jpeg_bytes = await request.read()

    if not jpeg_bytes:
        return aiohttp.web.Response(status=400, text="Empty body")

    # Save image
    ts_str = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S_%f")
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

    # Add to accumulator and create QR
    total_points, _ = accumulator.add_item(device_id, label)

    # Get all accumulated items for this device
    accumulated_items = accumulator.get_items(device_id)

    async def _try_qr() -> dict[str, Any] | None:
        try:
            return await asyncio.to_thread(create_intake_qr_sync, accumulated_items)
        except Exception as exc:
            print(f"  [Firebase] QR create failed: {exc}")
            return None

    qr_info = await _try_qr()

    response_body: dict[str, Any] = {
        "status": "ok",
        "id": row_id,
        "filename": filename,
    }

    if qr_info:
        response_body["qr"] = {
            "id": qr_info["id"],
            "payload": qr_info["payload"],
            "points": total_points,
            "qr_bitmap": qr_info["qr_bitmap"],
        }
        print(f"  [Firebase] QR created  id={qr_info['id']}  points={total_points}")

        # Store QR ID for this device
        accumulator.set_qr_id(device_id, qr_info["id"])

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
    start_firestore_listener()  # Start QR redemption listener
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
