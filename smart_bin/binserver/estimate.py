"""The paying formula, mirrored from the one implementation that actually credits
points: mobile/lib/services/qr_service.dart.

    per material:  points = round(weight_kg * 100 * (1.5 if free else 1.0))
    total:         sum over materials

Dart's `num.round()` rounds halves away from zero; Python's built-in `round()` uses
banker's rounding. `_round_half_away` reproduces Dart so the OLED estimate equals what
redemption pays. Both languages run the arithmetic in IEEE-754 doubles, so mirroring
the ops (not re-deriving "nice" values) is what keeps them in lockstep — see
test_estimate.py for the locked vectors.
"""

from __future__ import annotations

import math
from typing import Iterable, Protocol

BASE_MULTIPLIER = 100.0
FREE_MULTIPLIER = 1.5


class _Material(Protocol):
    weight: float
    is_free: bool


def _round_half_away(x: float) -> int:
    """Round to nearest, ties away from zero. Matches Dart num.round() for x >= 0."""
    if x >= 0:
        return math.floor(x + 0.5)
    return math.ceil(x - 0.5)


def points_for(weight_kg: float, is_free: bool) -> int:
    factor = FREE_MULTIPLIER if is_free else 1.0
    return _round_half_away(weight_kg * BASE_MULTIPLIER * factor)


def estimate_points(materials: Iterable[_Material]) -> int:
    return sum(points_for(m.weight, m.is_free) for m in materials)
