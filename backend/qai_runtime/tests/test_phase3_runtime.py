from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from app.config import RuntimeConfig
from app.metrics import RuntimeMetricsRenderer
from app.relay import OutboxRelay
from app.storage import RuntimeStore


class FakeIntegrations:
    def __init__(self, should_fail: bool = False):
        self.should_fail = should_fail
        self.events: list[tuple[str, str]] = []
        self.dead_letters: list[tuple[str, dict[str, object], str]] = []
        self.replays: list[tuple[str, dict[str, object], str, str]] = []

    def health_checks(self) -> dict[str, str]:
        return {"postgres": "connected", "redis": "connected", "kafka": "connected"}

    def dispatch_outbox_event(self, topic: str, payload_json: str) -> None:
        if self.should_fail:
            raise RuntimeError("relay-failed")
        self.events.append((topic, payload_json))

    def publish_dead_letter_event(self, event: dict[str, object], error: str) -> None:
        self.dead_letters.append((str(event["topic"]), event, error))

    def publish_replay_event(
        self,
        event: dict[str, object],
        previous_status: str,
        replay_source: str,
    ) -> None:
        self.replays.append((str(event["topic"]), event, previous_status, replay_source))


class Phase3RuntimeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        database_path = Path(self.tempdir.name) / "runtime.db"
        self.config = RuntimeConfig(
            database_path=database_path,
            postgres_dsn=None,
            redis_url=None,
            kafka_bootstrap_servers=None,
            kafka_orders_topic="orders.incoming",
            kafka_dead_letter_topic="orders.dead_letter",
            kafka_replay_topic="orders.replay",
            redis_idempotency_prefix="qai:idempotency:",
            relay_batch_size=25,
            relay_poll_interval_seconds=0.1,
            relay_retry_delay_seconds=0,
            relay_max_attempts=2,
            embedded_relay_enabled=False,
            require_postgres=False,
            require_redis=False,
            require_kafka=False,
        )
        self.store = RuntimeStore(database_path)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def _payload(self) -> dict[str, object]:
        return {
            "id": "order-1",
            "symbol": "BTCUSDT",
            "side": "BUY",
            "price": 100_000.0,
            "amount": 0.25,
            "timestamp": 1_712_345_678.0,
        }

    def test_record_order_enqueues_outbox_event(self) -> None:
        inserted = self.store.record_order(self._payload(), "idem-1", self.config.kafka_orders_topic)

        self.assertTrue(inserted)
        self.assertEqual(self.store.order_count(), 1)
        self.assertEqual(self.store.outbox_stats()["pending"], 1)

    def test_outbox_relay_marks_events_sent(self) -> None:
        self.store.record_order(self._payload(), "idem-1", self.config.kafka_orders_topic)
        integrations = FakeIntegrations()
        relay = OutboxRelay(self.store, integrations, self.config)

        result = relay.drain_once()

        self.assertEqual(result.sent, 1)
        self.assertEqual(len(integrations.events), 1)
        self.assertEqual(self.store.outbox_stats()["sent"], 1)
        self.assertEqual(self.store.relay_audit_counts()["sent"], 1)
        snapshots = self.store.list_metrics_snapshots(limit=2)
        self.assertTrue(len(snapshots) >= 1)
        self.assertEqual(snapshots[-1]["relay_sent"], 1)

    def test_outbox_relay_marks_failures_for_retry(self) -> None:
        self.store.record_order(self._payload(), "idem-1", self.config.kafka_orders_topic)
        relay = OutboxRelay(self.store, FakeIntegrations(should_fail=True), self.config)

        result = relay.drain_once()

        self.assertEqual(result.failed, 1)
        self.assertEqual(self.store.outbox_stats()["failed"], 1)

    def test_outbox_relay_moves_event_to_dead_letter_after_max_attempts(self) -> None:
        self.store.record_order(self._payload(), "idem-1", self.config.kafka_orders_topic)
        integrations = FakeIntegrations(should_fail=True)
        relay = OutboxRelay(self.store, integrations, self.config)

        relay.drain_once()
        result = relay.drain_once()

        self.assertEqual(result.dead_lettered, 1)
        self.assertEqual(self.store.outbox_stats()["dead_letter"], 1)
        self.assertEqual(len(integrations.dead_letters), 1)
        self.assertEqual(self.store.relay_audit_counts()["dead_letter"], 1)
        topic_activity = self.store.list_topic_activity(limit=2)
        self.assertEqual(topic_activity[0]["topic"], "orders.dead_letter")

    def test_dead_letter_event_can_be_replayed_and_delivered(self) -> None:
        self.store.record_order(self._payload(), "idem-1", self.config.kafka_orders_topic)
        failing = OutboxRelay(self.store, FakeIntegrations(should_fail=True), self.config)
        failing.drain_once()
        event_id = self.store.list_outbox_events(status="failed", limit=1)[0]["id"]
        self.store.replay_outbox_event(int(event_id))
        passing = OutboxRelay(self.store, FakeIntegrations(), self.config)

        result = passing.drain_once()

        self.assertEqual(result.sent, 1)
        self.assertEqual(self.store.outbox_stats()["sent"], 1)

    def test_relay_audit_listing_supports_action_topic_and_status_filters(self) -> None:
        self.store.record_relay_audit("sent", 1, "orders.incoming", "published", "ok")
        self.store.record_relay_audit("replay", 1, "orders.replay", "published", "manual")
        self.store.record_relay_audit("dead_letter", 1, "orders.dead_letter", "publish_failed", "timeout")

        replay_only = self.store.list_relay_audits(limit=10, actions=["replay"])
        failed_only = self.store.list_relay_audits(limit=10, statuses=["publish_failed"])
        replay_topic = self.store.list_relay_audits(limit=10, topics=["orders.replay"])

        self.assertEqual(len(replay_only), 1)
        self.assertEqual(replay_only[0]["action"], "replay")
        self.assertEqual(len(failed_only), 1)
        self.assertEqual(failed_only[0]["topic"], "orders.dead_letter")
        self.assertEqual(len(replay_topic), 1)
        self.assertEqual(replay_topic[0]["status"], "published")

    def test_outbox_listing_supports_multi_status_and_topic_filters(self) -> None:
        payload = self._payload()
        self.store.record_order(payload, "idem-1", self.config.kafka_orders_topic)
        self.store.record_order({**payload, "id": "order-2"}, "idem-2", self.config.kafka_dead_letter_topic)
        self.store.mark_outbox_failed(
            event_id=1,
            error="timeout",
            attempt_number=1,
            retry_delay_seconds=0,
            max_attempts=3,
        )

        filtered = self.store.list_outbox_events(
            limit=10,
            statuses=["failed", "dead_letter"],
            topic=self.config.kafka_orders_topic,
        )

        self.assertEqual(len(filtered), 1)
        self.assertEqual(filtered[0]["aggregate_id"], "order-1")
        self.assertEqual(filtered[0]["status"], "failed")

    def test_metrics_renderer_exposes_runtime_gauges(self) -> None:
        self.store.record_order(self._payload(), "idem-1", self.config.kafka_orders_topic)
        OutboxRelay(self.store, FakeIntegrations(should_fail=True), self.config).drain_once()
        metrics = RuntimeMetricsRenderer(self.store, FakeIntegrations())

        rendered = metrics.render()

        self.assertIn("qai_orders_total 1", rendered)
        self.assertIn("qai_relay_attempts_total 1.0", rendered)
        self.assertIn('qai_outbox_events{status="failed"} 1', rendered)
        self.assertIn('qai_outbox_oldest_age_seconds{bucket="retryable"}', rendered)
        self.assertIn('qai_dependency_up{name="postgres"} 1', rendered)
        self.assertIn('qai_relay_audit_total{action="dead_letter"} 0', rendered)


if __name__ == "__main__":
    unittest.main()
