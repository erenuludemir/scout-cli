from __future__ import annotations

import threading
from dataclasses import dataclass

from .config import RuntimeConfig
from .integrations import RuntimeIntegrations
from .storage import RuntimeStore


@dataclass(frozen=True)
class RelayResult:
    claimed: int = 0
    sent: int = 0
    failed: int = 0
    dead_lettered: int = 0


class OutboxRelay:
    def __init__(
        self,
        store: RuntimeStore,
        integrations: RuntimeIntegrations,
        config: RuntimeConfig,
    ):
        self.store = store
        self.integrations = integrations
        self.config = config

    def drain_once(self) -> RelayResult:
        claimed = self.store.claim_outbox_batch(self.config.relay_batch_size)
        sent = 0
        failed = 0
        dead_lettered = 0
        for event in claimed:
            try:
                self.integrations.dispatch_outbox_event(event["topic"], event["payload"])
                self.store.mark_outbox_sent(int(event["id"]))
                self.store.record_relay_audit(
                    action="sent",
                    event_id=int(event["id"]),
                    topic=str(event["topic"]),
                    status="sent",
                )
                self.store.record_metrics_snapshot(self.integrations.health_checks())
                sent += 1
            except Exception as exc:
                next_status = self.store.mark_outbox_failed(
                    int(event["id"]),
                    str(exc),
                    self.config.relay_retry_delay_seconds,
                    self.config.relay_max_attempts,
                    int(event["attempts"]),
                )
                if next_status == "dead_letter":
                    self._record_dead_letter(event, str(exc))
                    dead_lettered += 1
                else:
                    self.store.record_metrics_snapshot(self.integrations.health_checks())
                    failed += 1
        return RelayResult(
            claimed=len(claimed),
            sent=sent,
            failed=failed,
            dead_lettered=dead_lettered,
        )

    def run_forever(self, stop_event: threading.Event) -> None:
        while not stop_event.is_set():
            result = self.drain_once()
            wait_time = 0.1 if result.claimed else self.config.relay_poll_interval_seconds
            stop_event.wait(wait_time)

    def _record_dead_letter(self, event: dict[str, object], error: str) -> None:
        status = "published"
        detail = error[:500]
        try:
            self.integrations.publish_dead_letter_event(event, error)
        except Exception as exc:
            status = "publish_failed"
            detail = f"{detail} | kafka={str(exc)[:220]}"
        self.store.record_relay_audit(
            action="dead_letter",
            event_id=int(event["id"]),
            topic=self.config.kafka_dead_letter_topic,
            status=status,
            detail=detail,
        )
        self.store.record_metrics_snapshot(self.integrations.health_checks())


class EmbeddedRelayRunner:
    def __init__(self, relay: OutboxRelay):
        self.relay = relay
        self._stop_event = threading.Event()
        self._thread: threading.Thread | None = None

    def start(self) -> None:
        if self._thread and self._thread.is_alive():
            return
        self._stop_event.clear()
        self._thread = threading.Thread(
            target=self.relay.run_forever,
            args=(self._stop_event,),
            daemon=True,
            name="qai-outbox-relay",
        )
        self._thread.start()

    def stop(self) -> None:
        self._stop_event.set()
        if self._thread:
            self._thread.join(timeout=5)
