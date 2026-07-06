"""Smart Recycle Bin server.

The intake session (see CONTEXT.md) has one owning module — `session.IntakeSession`,
pure and synchronous. Everything with a socket, a clock, or a Firestore handle lives
in `runtime.SessionRuntime` (the async shell) and the transport adapters. Persistence
sits behind the `ledger.QrLedger` seam.

Entry point: `binserver.app.run`. The repo's `smart_bin/server.py` is a thin shim
over it so `python server.py` keeps working.
"""
