"""Runtime configuration, resolved from the environment.

No credential path or center id is baked into the source any more (the old server.py
hardcoded both). Missing Firebase config is a loud evidence-only mode, decided in
app.build_ledger — not a silent fallback.
"""

from __future__ import annotations

import os
from dataclasses import dataclass, field

# Payload prefix the mobile app scans: "KITAKITAR_QR:<docId>" (kQrPayloadPrefix).
KITAKITAR_QR_PREFIX = "KITAKITAR_QR:"

# Model label -> (Firestore material type, weight kg). The classifier emits these two
# labels; center materials use the snake_case types in center_web/kMaterialTypes.
LABEL_TO_TYPE_WEIGHT: dict[str, tuple[str, float]] = {
    "paper": ("paper", 0.005),
    "can": ("aluminum", 0.015),
}


def _f(name: str, default: float) -> float:
    raw = os.environ.get(name)
    return float(raw) if raw not in (None, "") else default


def _s(name: str, default: str) -> str:
    raw = os.environ.get(name)
    return raw if raw not in (None, "") else default


@dataclass(frozen=True)
class Config:
    db_path: str = "recycle_data.db"
    image_dir: str = "captured_images"

    ws_host: str = "0.0.0.0"
    ws_port: int = 8765
    http_host: str = "0.0.0.0"
    http_port: int = 8766

    center_id: str | None = None
    service_account: str | None = None
    demo_mode: bool = False

    # Acceptance gate. Confidence is a percent (the firmware sends round(value*1000)/10).
    min_confidence: float = 60.0
    accept_cooldown: float = 3.0

    # Fixed at 30 s: the frozen firmware runs its own hardcoded 30 s countdown, so any
    # other value would make the OLED disagree with the server.
    session_deadline: float = 30.0
    grace_tail: float = 300.0  # 5 min a QR stays redeemable after the display clears

    qr_prefix: str = KITAKITAR_QR_PREFIX
    label_to_type_weight: dict[str, tuple[str, float]] = field(
        default_factory=lambda: dict(LABEL_TO_TYPE_WEIGHT)
    )
    upload_max_bytes: int = 5 * 1024 * 1024

    @classmethod
    def from_env(cls) -> "Config":
        service_account = (
            os.environ.get("FIREBASE_SERVICE_ACCOUNT")
            or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
            or None
        )
        return cls(
            db_path=_s("SMART_BIN_DB_PATH", "recycle_data.db"),
            image_dir=_s("SMART_BIN_IMAGE_DIR", "captured_images"),
            ws_host=_s("SMART_BIN_WS_HOST", "0.0.0.0"),
            ws_port=int(_f("SMART_BIN_WS_PORT", 8765)),
            http_host=_s("SMART_BIN_HTTP_HOST", "0.0.0.0"),
            http_port=int(_f("SMART_BIN_HTTP_PORT", 8766)),
            center_id=os.environ.get("SMART_BIN_CENTER_ID") or None,
            service_account=service_account,
            demo_mode=os.environ.get("SMART_BIN_DEMO", "").lower() in ("1", "true", "yes"),
            min_confidence=_f("SMART_BIN_MIN_CONFIDENCE", 60.0),
            accept_cooldown=_f("SMART_BIN_ACCEPT_COOLDOWN", 3.0),
            grace_tail=_f("SMART_BIN_GRACE_TAIL", 300.0),
        )
