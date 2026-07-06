"""QR payload -> 1-bit 64x64 bitmap for the SSD1306 OLED.

Byte layout matches the firmware's renderQrDisplay exactly: bit index = y*64 + x,
MSB first, 8 pixels per byte -> 512 bytes for 64x64. The device reads it back the
same way, so this ordering is load-bearing, not a choice.
"""

from __future__ import annotations

import segno

OLED_SIZE = 64
BITMAP_BYTES = (OLED_SIZE * OLED_SIZE + 7) // 8  # 512


def make_payload(qr_id: str, prefix: str) -> str:
    return f"{prefix}{qr_id}"


def matrix_to_oled_bytes(matrix, size: int = OLED_SIZE) -> list[int]:
    """Nearest-neighbour scale a QR module matrix into a size*size packed bitmap."""
    rows = [list(r) for r in matrix]
    modules = len(rows)
    scale = max(1, size // modules) if modules else 1

    out = [0] * ((size * size + 7) // 8)
    for ry, row in enumerate(rows):
        for cx, module in enumerate(row):
            if not module:
                continue
            for dy in range(scale):
                y = ry * scale + dy
                if y >= size:
                    break
                base = y * size
                for dx in range(scale):
                    x = cx * scale + dx
                    if x >= size:
                        break
                    bit = base + x
                    out[bit >> 3] |= 1 << (7 - (bit & 7))
    return out


def qr_bitmap(payload: str, size: int = OLED_SIZE) -> list[int]:
    qr = segno.make(payload)
    return matrix_to_oled_bytes(qr.matrix, size)
