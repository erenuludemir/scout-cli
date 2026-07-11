from __future__ import annotations

import signal
import threading

from .config import RuntimeConfig
from .integrations import RuntimeIntegrations
from .relay import OutboxRelay
from .storage import RuntimeStore


def main() -> None:
    config = RuntimeConfig.load()
    store = RuntimeStore(config.database_path)
    integrations = RuntimeIntegrations(config)
    integrations.bootstrap()
    relay = OutboxRelay(store, integrations, config)
    stop_event = threading.Event()
    signal.signal(signal.SIGINT, lambda *_: stop_event.set())
    signal.signal(signal.SIGTERM, lambda *_: stop_event.set())
    relay.run_forever(stop_event)


if __name__ == "__main__":
    main()
