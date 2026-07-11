from __future__ import annotations

import json
from typing import Any

from .config import RuntimeConfig


def _load_psycopg():
    try:
        import psycopg  # type: ignore
    except ModuleNotFoundError:
        return None
    return psycopg


def _load_redis():
    try:
        import redis  # type: ignore
    except ModuleNotFoundError:
        return None
    return redis


def _load_kafka_producer():
    try:
        from kafka import KafkaProducer  # type: ignore
    except ModuleNotFoundError:
        return None
    return KafkaProducer


class RuntimeIntegrations:
    def __init__(self, config: RuntimeConfig):
        self.config = config
        self._postgres_bootstrapped = False

    def health_checks(self) -> dict[str, str]:
        return {
            "postgres": self._postgres_status(),
            "redis": self._redis_status(),
            "kafka": self._kafka_status(),
        }

    def bootstrap(self) -> None:
        if self.config.postgres_enabled:
            self._ensure_postgres_schema()

    def dispatch_outbox_event(self, topic: str, payload_json: str) -> None:
        payload = json.loads(payload_json)
        if topic != self.config.kafka_orders_topic:
            raise ValueError(f"unsupported outbox topic: {topic}")
        order = payload["order"]
        idempotency_key = payload["idempotency_key"]
        self._mirror_order_to_postgres(order, idempotency_key)
        self._mirror_order_to_redis(order, idempotency_key)
        self._publish_order_event(order, idempotency_key)

    def publish_dead_letter_event(self, event: dict[str, Any], error: str) -> None:
        payload = self._build_signal_payload(
            event=event,
            state="dead_letter",
            detail={"last_error": error[:500]},
        )
        self._publish_runtime_signal(
            self.config.kafka_dead_letter_topic,
            key=str(event["idempotency_key"]),
            payload=payload,
        )

    def publish_replay_event(
        self,
        event: dict[str, Any],
        previous_status: str,
        replay_source: str,
    ) -> None:
        payload = self._build_signal_payload(
            event=event,
            state="replay",
            detail={
                "previous_status": previous_status,
                "replay_source": replay_source,
            },
        )
        self._publish_runtime_signal(
            self.config.kafka_replay_topic,
            key=str(event["idempotency_key"]),
            payload=payload,
        )

    def _postgres_status(self) -> str:
        if not self.config.postgres_enabled:
            return "optional"
        if not self.config.postgres_dsn:
            return "not-configured"
        psycopg = _load_psycopg()
        if psycopg is None:
            return "module-missing"
        try:
            with psycopg.connect(self.config.postgres_dsn, connect_timeout=2) as conn:
                with conn.cursor() as cur:
                    cur.execute("SELECT 1")
                    cur.fetchone()
            return "connected"
        except Exception:
            return "unreachable"

    def _redis_status(self) -> str:
        if not self.config.redis_enabled:
            return "optional"
        if not self.config.redis_url:
            return "not-configured"
        redis = _load_redis()
        if redis is None:
            return "module-missing"
        try:
            client = redis.from_url(self.config.redis_url, decode_responses=True, socket_timeout=2)
            return "connected" if client.ping() else "unreachable"
        except Exception:
            return "unreachable"

    def _kafka_status(self) -> str:
        if not self.config.kafka_enabled:
            return "optional"
        if not self.config.kafka_bootstrap_servers:
            return "not-configured"
        producer_type = _load_kafka_producer()
        if producer_type is None:
            return "module-missing"
        try:
            producer = producer_type(
                bootstrap_servers=self.config.kafka_bootstrap_servers,
                request_timeout_ms=2000,
                api_version_auto_timeout_ms=2000,
            )
            if not producer.bootstrap_connected():
                producer.close()
                return "unreachable"
            producer.close()
            return "connected"
        except Exception:
            return "unreachable"

    def _ensure_postgres_schema(self) -> None:
        if self._postgres_bootstrapped:
            return
        psycopg = _load_psycopg()
        if psycopg is None or not self.config.postgres_dsn:
            return
        with psycopg.connect(self.config.postgres_dsn, connect_timeout=2) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS runtime_orders (
                        id TEXT PRIMARY KEY,
                        idempotency_key TEXT NOT NULL UNIQUE,
                        symbol TEXT NOT NULL,
                        side TEXT NOT NULL,
                        price DOUBLE PRECISION NOT NULL,
                        amount DOUBLE PRECISION NOT NULL,
                        timestamp DOUBLE PRECISION NOT NULL,
                        source TEXT NOT NULL DEFAULT 'runtime-api',
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
            conn.commit()
        self._postgres_bootstrapped = True

    def _mirror_order_to_postgres(self, payload: dict[str, Any], idempotency_key: str) -> None:
        if not self.config.postgres_enabled:
            return
        psycopg = _load_psycopg()
        if psycopg is None or not self.config.postgres_dsn:
            return
        self._ensure_postgres_schema()
        with psycopg.connect(self.config.postgres_dsn, connect_timeout=2) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO runtime_orders (
                        id, idempotency_key, symbol, side, price, amount, timestamp
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (idempotency_key) DO NOTHING
                    """,
                    (
                        payload["id"],
                        idempotency_key,
                        payload["symbol"],
                        payload["side"],
                        payload["price"],
                        payload["amount"],
                        payload["timestamp"],
                    ),
                )
            conn.commit()

    def _mirror_order_to_redis(self, payload: dict[str, Any], idempotency_key: str) -> None:
        if not self.config.redis_enabled:
            return
        redis = _load_redis()
        if redis is None or not self.config.redis_url:
            return
        client = redis.from_url(self.config.redis_url, decode_responses=True, socket_timeout=2)
        cache_key = f"{self.config.redis_idempotency_prefix}{idempotency_key}"
        order_key = f"qai:orders:{payload['id']}"
        client.set(cache_key, payload["id"], ex=86_400, nx=True)
        client.hset(order_key, mapping={k: str(v) for k, v in payload.items()})
        client.expire(order_key, 86_400)

    def _publish_order_event(self, payload: dict[str, Any], idempotency_key: str) -> None:
        self._publish_runtime_signal(
            self.config.kafka_orders_topic,
            key=idempotency_key,
            payload={"order": payload, "idempotency_key": idempotency_key},
        )

    def _publish_runtime_signal(
        self,
        topic: str,
        key: str,
        payload: dict[str, Any],
    ) -> None:
        if not self.config.kafka_enabled:
            return
        producer_type = _load_kafka_producer()
        if producer_type is None or not self.config.kafka_bootstrap_servers:
            return
        producer = producer_type(
            bootstrap_servers=self.config.kafka_bootstrap_servers,
            value_serializer=lambda value: json.dumps(value).encode("utf-8"),
            key_serializer=lambda value: value.encode("utf-8"),
            request_timeout_ms=3000,
            retries=1,
        )
        producer.send(topic, key=key, value=payload).get(timeout=3)
        producer.flush()
        producer.close()

    def _build_signal_payload(
        self,
        event: dict[str, Any],
        state: str,
        detail: dict[str, Any],
    ) -> dict[str, Any]:
        return {
            "event_id": int(event["id"]),
            "aggregate_id": str(event["aggregate_id"]),
            "idempotency_key": str(event["idempotency_key"]),
            "source_topic": str(event["topic"]),
            "state": state,
            "attempts": int(event["attempts"]),
            "detail": detail,
            "payload": json.loads(str(event["payload"])),
        }
