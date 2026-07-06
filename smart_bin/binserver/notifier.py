"""DeviceRegistry — the outbound seam to a connected device.

Sends drop silently when the device is offline: the firmware runs its own local
countdown, so a missed frame self-heals on the display. unregister only removes the
socket if it is still the current one for that device — this kills the reconnect race
the old server had, where a late disconnect of an old socket wiped a freshly
reconnected one.
"""

from __future__ import annotations

from typing import Protocol


class Connection(Protocol):
    async def send_json(self, data: dict) -> None: ...


class DeviceRegistry:
    def __init__(self):
        self._by_device: dict[str, Connection] = {}

    def register(self, device_id: str, conn: Connection) -> None:
        self._by_device[device_id] = conn

    def unregister(self, device_id: str, conn: Connection) -> None:
        if self._by_device.get(device_id) is conn:
            del self._by_device[device_id]

    def is_online(self, device_id: str) -> bool:
        return device_id in self._by_device

    async def send(self, device_id: str, message: dict) -> bool:
        conn = self._by_device.get(device_id)
        if conn is None:
            return False
        try:
            await conn.send_json(message)
            return True
        except Exception:
            # stale socket; drop it so we stop trying
            self.unregister(device_id, conn)
            return False
