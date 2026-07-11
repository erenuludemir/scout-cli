from __future__ import annotations

import signal
from typing import Callable


_SHUTDOWN = False


def is_shutdown_requested() -> bool:
    return _SHUTDOWN


def install_shutdown_handlers(on_shutdown: Callable[[str], None]) -> None:
    def _handler(signum: int, _frame: object) -> None:
        global _SHUTDOWN
        if _SHUTDOWN:
            return
        _SHUTDOWN = True
        on_shutdown(signal.Signals(signum).name)

    signal.signal(signal.SIGTERM, _handler)
    signal.signal(signal.SIGINT, _handler)
    if hasattr(signal, "SIGHUP"):
        signal.signal(signal.SIGHUP, _handler)
