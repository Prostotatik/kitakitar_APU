"""QrLedger — the seam in front of QR persistence.

Two real adapters justify the seam: FirestoreLedger in production, InMemoryLedger in
tests and explicit demo mode. NullLedger is the loud evidence-only degradation when
Firebase is not configured. The runtime talks only to this interface.

publish is split into create/supersede so the seam is explicit about the one-doc,
updated-in-place invariant: a session creates exactly one doc and revises it. supersede
carries a `used == false` precondition; if redemption won the race it raises Redeemed
and the runtime re-seeds a fresh session (never losing the pending item).
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Callable, Protocol
import uuid

from .session import Draft


class Redeemed(Exception):
    """Raised by supersede/void when the doc was already redeemed (used == true)."""


@dataclass(frozen=True)
class MaterialPrice:
    price_per_kg: float
    is_free: bool


OnRedeemed = Callable[[str], None]


class Watch(Protocol):
    def cancel(self) -> None: ...


class QrLedger(Protocol):
    def prices(self) -> dict[str, MaterialPrice]: ...
    def create(self, draft: Draft) -> str: ...
    def supersede(self, qr_id: str, draft: Draft) -> None: ...
    def void(self, qr_id: str) -> None: ...
    def watch(self, qr_id: str, on_redeemed: OnRedeemed) -> Watch: ...
    def sweep_pending(self, older_than_epoch: float) -> int: ...


def draft_to_materials(draft: Draft) -> list[dict]:
    """The /qr_codes transactionDraft.materials shape, identical to center_web."""
    return [
        {
            "type": m.type,
            "weight": m.weight,
            "pricePerKg": m.price_per_kg,
            "isFree": m.is_free,
        }
        for m in draft.materials
    ]


# ── In-memory adapter (tests + demo) ─────────────────────────────────────────
class _MemWatch:
    def __init__(self, ledger: "InMemoryLedger", qr_id: str):
        self._ledger = ledger
        self._qr_id = qr_id
        self.cancelled = False

    def cancel(self) -> None:
        self.cancelled = True
        self._ledger._watches.pop(self._qr_id, None)


class InMemoryLedger:
    """Deterministic ledger for tests and `SMART_BIN_DEMO=1`. Nothing persists."""

    def __init__(self, prices: dict[str, MaterialPrice] | None = None):
        self._prices = dict(prices or {})
        self.docs: dict[str, dict] = {}
        self._watches: dict[str, tuple[_MemWatch, OnRedeemed]] = {}
        self.created: list[str] = []
        self.superseded: list[str] = []
        self.voided: list[str] = []

    def prices(self) -> dict[str, MaterialPrice]:
        return dict(self._prices)

    def create(self, draft: Draft) -> str:
        qr_id = uuid.uuid4().hex[:20]
        self.docs[qr_id] = {
            "centerId": "mem",
            "transactionDraft": {
                "materials": draft_to_materials(draft),
                "totalWeight": draft.total_weight,
            },
            "used": False,
            "createdAt": datetime.now(timezone.utc),
        }
        self.created.append(qr_id)
        return qr_id

    def supersede(self, qr_id: str, draft: Draft) -> None:
        doc = self.docs.get(qr_id)
        if doc is None or doc["used"]:
            raise Redeemed()
        doc["transactionDraft"] = {
            "materials": draft_to_materials(draft),
            "totalWeight": draft.total_weight,
        }
        self.superseded.append(qr_id)

    def void(self, qr_id: str) -> None:
        doc = self.docs.get(qr_id)
        if doc is None:
            return
        if doc["used"]:
            raise Redeemed()
        del self.docs[qr_id]
        self.voided.append(qr_id)

    def watch(self, qr_id: str, on_redeemed: OnRedeemed) -> Watch:
        w = _MemWatch(self, qr_id)
        self._watches[qr_id] = (w, on_redeemed)
        return w

    def sweep_pending(self, older_than_epoch: float) -> int:
        cutoff = datetime.fromtimestamp(older_than_epoch, tz=timezone.utc)
        stale = [
            qid
            for qid, doc in self.docs.items()
            if not doc["used"] and doc["createdAt"] < cutoff
        ]
        for qid in stale:
            del self.docs[qid]
        return len(stale)

    # test helper: simulate the mobile app redeeming a QR
    def simulate_redeem(self, qr_id: str) -> None:
        doc = self.docs.get(qr_id)
        if doc is None or doc["used"]:
            return
        doc["used"] = True
        pair = self._watches.get(qr_id)
        if pair is not None:
            pair[1](qr_id)


# ── Null adapter (loud evidence-only mode) ───────────────────────────────────
class NullLedger:
    """No Firebase -> no QR. The runtime runs with qr_enabled=False and never calls
    these, but the object exists so wiring stays uniform."""

    def prices(self) -> dict[str, MaterialPrice]:
        return {}

    def create(self, draft: Draft) -> str:
        raise RuntimeError("QR disabled (evidence-only mode)")

    def supersede(self, qr_id: str, draft: Draft) -> None:
        raise RuntimeError("QR disabled (evidence-only mode)")

    def void(self, qr_id: str) -> None:
        pass

    def watch(self, qr_id: str, on_redeemed: OnRedeemed) -> Watch:
        raise RuntimeError("QR disabled (evidence-only mode)")

    def sweep_pending(self, older_than_epoch: float) -> int:
        return 0


# ── Firestore adapter (production) ───────────────────────────────────────────
class _FirestoreWatch:
    def __init__(self, watch):
        self._watch = watch

    def cancel(self) -> None:
        try:
            self._watch.unsubscribe()
        except Exception:
            pass


class FirestoreLedger:
    """Writes /qr_codes docs in the shape mobile redemption expects. Prices are cached
    once at construction. Redemption is watched per-doc; the adapter calls on_redeemed
    from a gRPC background thread — the runtime's callback is what marshals onto the
    event loop, so this class stays loop-agnostic."""

    def __init__(self, center_id: str, service_account_path: str):
        import firebase_admin
        from firebase_admin import credentials, firestore

        try:
            firebase_admin.get_app()
        except ValueError:
            firebase_admin.initialize_app(credentials.Certificate(service_account_path))

        self._firestore = firestore
        self._db = firestore.client()
        self._center_id = center_id
        self._server_timestamp = firestore.SERVER_TIMESTAMP
        self._prices = self._load_prices()

    def _load_prices(self) -> dict[str, MaterialPrice]:
        prices: dict[str, MaterialPrice] = {}
        col = (
            self._db.collection("centers")
            .document(self._center_id)
            .collection("materials")
        )
        for snap in col.stream():
            data = snap.to_dict() or {}
            mtype = data.get("type")
            if not mtype:
                continue
            price = float(data.get("pricePerKg") or 0.0)
            prices[mtype] = MaterialPrice(price, price <= 0)
        return prices

    def prices(self) -> dict[str, MaterialPrice]:
        return dict(self._prices)

    def create(self, draft: Draft) -> str:
        _, ref = self._db.collection("qr_codes").add(
            {
                "centerId": self._center_id,
                "transactionDraft": {
                    "materials": draft_to_materials(draft),
                    "totalWeight": draft.total_weight,
                },
                "used": False,
                "createdAt": self._server_timestamp,
            }
        )
        return ref.id

    def supersede(self, qr_id: str, draft: Draft) -> None:
        ref = self._db.collection("qr_codes").document(qr_id)
        transaction = self._db.transaction()
        payload = {
            "materials": draft_to_materials(draft),
            "totalWeight": draft.total_weight,
        }

        @self._firestore.transactional
        def _apply(txn):
            snap = ref.get(transaction=txn)
            if not snap.exists or snap.get("used"):
                raise Redeemed()
            txn.update(ref, {"transactionDraft": payload})

        _apply(transaction)

    def void(self, qr_id: str) -> None:
        ref = self._db.collection("qr_codes").document(qr_id)
        transaction = self._db.transaction()

        @self._firestore.transactional
        def _apply(txn):
            snap = ref.get(transaction=txn)
            if not snap.exists:
                return
            if snap.get("used"):
                raise Redeemed()
            txn.delete(ref)

        _apply(transaction)

    def watch(self, qr_id: str, on_redeemed: OnRedeemed) -> Watch:
        ref = self._db.collection("qr_codes").document(qr_id)

        def _on_snapshot(snapshot, changes, read_time):
            snap = snapshot[0] if isinstance(snapshot, list) else snapshot
            if snap is not None and getattr(snap, "exists", False):
                data = snap.to_dict() or {}
                if data.get("used") is True:
                    on_redeemed(qr_id)

        return _FirestoreWatch(ref.on_snapshot(_on_snapshot))

    def sweep_pending(self, older_than_epoch: float) -> int:
        cutoff = datetime.fromtimestamp(older_than_epoch, tz=timezone.utc)
        query = (
            self._db.collection("qr_codes")
            .where("centerId", "==", self._center_id)
            .where("used", "==", False)
        )
        removed = 0
        for snap in query.stream():
            created = snap.get("createdAt")
            if created is None or created < cutoff:
                snap.reference.delete()
                removed += 1
        return removed
