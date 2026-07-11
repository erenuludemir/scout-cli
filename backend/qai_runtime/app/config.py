from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class RuntimeConfig:
    database_path: Path
    postgres_dsn: str | None
    redis_url: str | None
    kafka_bootstrap_servers: str | None
    kafka_orders_topic: str
    kafka_dead_letter_topic: str
    kafka_replay_topic: str
    redis_idempotency_prefix: str
    relay_batch_size: int
    relay_poll_interval_seconds: float
    relay_retry_delay_seconds: int
    relay_max_attempts: int
    embedded_relay_enabled: bool
    require_postgres: bool
    require_redis: bool
    require_kafka: bool

    @property
    def postgres_enabled(self) -> bool:
        return self.require_postgres or bool(self.postgres_dsn)

    @property
    def redis_enabled(self) -> bool:
        return self.require_redis or bool(self.redis_url)

    @property
    def kafka_enabled(self) -> bool:
        return self.require_kafka or bool(self.kafka_bootstrap_servers)

    @classmethod
    def load(cls) -> "RuntimeConfig":
        root = Path(__file__).resolve().parents[1]
        return cls(
            database_path=Path(os.getenv("QAI_DB_PATH", root / "data" / "runtime.db")),
            postgres_dsn=os.getenv("QAI_POSTGRES_DSN") or os.getenv("DATABASE_URL"),
            redis_url=os.getenv("QAI_REDIS_URL") or os.getenv("REDIS_URL"),
            kafka_bootstrap_servers=os.getenv("QAI_KAFKA_BOOTSTRAP_SERVERS") or os.getenv("KAFKA_BROKERS"),
            kafka_orders_topic=os.getenv("QAI_KAFKA_ORDERS_TOPIC", "orders.incoming"),
            kafka_dead_letter_topic=os.getenv("QAI_KAFKA_DEAD_LETTER_TOPIC", "orders.dead_letter"),
            kafka_replay_topic=os.getenv("QAI_KAFKA_REPLAY_TOPIC", "orders.replay"),
            redis_idempotency_prefix=os.getenv("QAI_REDIS_IDEMPOTENCY_PREFIX", "qai:idempotency:"),
            relay_batch_size=int(os.getenv("QAI_RELAY_BATCH_SIZE", "50")),
            relay_poll_interval_seconds=float(os.getenv("QAI_RELAY_POLL_INTERVAL", "2")),
            relay_retry_delay_seconds=int(os.getenv("QAI_RELAY_RETRY_DELAY", "5")),
            relay_max_attempts=int(os.getenv("QAI_RELAY_MAX_ATTEMPTS", "3")),
            embedded_relay_enabled=os.getenv("QAI_ENABLE_EMBEDDED_RELAY", "1") == "1",
            require_postgres=os.getenv("QAI_REQUIRE_POSTGRES", "0") == "1",
            require_redis=os.getenv("QAI_REQUIRE_REDIS", "0") == "1",
            require_kafka=os.getenv("QAI_REQUIRE_KAFKA", "0") == "1",
        )
