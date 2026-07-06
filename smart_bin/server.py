"""Entry shim so `python server.py` keeps working.

The server is the `binserver/` package. IntakeSession (binserver/session.py) owns the
intake run; SessionRuntime (binserver/runtime.py) is the async shell; QR persistence
sits behind binserver/ledger.py. See smart_bin/CONTEXT-notes or the repo CONTEXT.md.

Config comes from the environment (binserver/config.py) — nothing is hardcoded:
    SMART_BIN_CENTER_ID          centers/{id} for this bin
    FIREBASE_SERVICE_ACCOUNT     path to the service-account JSON
                                 (or GOOGLE_APPLICATION_CREDENTIALS)
    SMART_BIN_DEMO=1             in-memory ledger, no Firebase
"""

from __future__ import annotations

import asyncio

from binserver.app import run

if __name__ == "__main__":
    try:
        asyncio.run(run())
    except KeyboardInterrupt:
        print("\n[!] Server stopped.")
