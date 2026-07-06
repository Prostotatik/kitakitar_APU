"""Evidence — the audit trail from the HTTP photo upload. A photo file plus one row
in SQLite. Never touches a session and never mints a QR: a photo is proof an item was
seen, not the intake event (that is the WS frame; see CONTEXT.md).

Schema is unchanged from the original server so existing analytics keep reading it.
Functions are plain blocking calls; the HTTP adapter runs them off the event loop.
"""

from __future__ import annotations

import os
import sqlite3
from datetime import datetime, timezone

_SCHEMA = """
CREATE TABLE IF NOT EXISTS detections (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id   TEXT    NOT NULL,
    label       TEXT    NOT NULL,
    confidence  REAL    NOT NULL,
    image_path  TEXT    NOT NULL,
    timestamp   TEXT    NOT NULL
)
"""


def init_storage(db_path: str, image_dir: str) -> None:
    os.makedirs(image_dir, exist_ok=True)
    with sqlite3.connect(db_path) as conn:
        conn.execute(_SCHEMA)


def save_photo(image_dir: str, label: str, jpeg: bytes) -> str:
    ts = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S_%f")
    path = os.path.join(image_dir, f"{label}_{ts}.jpg")
    with open(path, "wb") as f:
        f.write(jpeg)
    return path


def record_detection(
    db_path: str, device_id: str, label: str, confidence: float, image_path: str
) -> int:
    ts = datetime.now(timezone.utc).isoformat()
    with sqlite3.connect(db_path) as conn:
        cur = conn.execute(
            "INSERT INTO detections (device_id, label, confidence, image_path, timestamp) "
            "VALUES (?, ?, ?, ?, ?)",
            (device_id, label, confidence, image_path, ts),
        )
        return cur.lastrowid
