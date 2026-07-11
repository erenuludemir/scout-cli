from __future__ import annotations

import json
import sqlite3
from contextlib import closing
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any


class RuntimeStore:
    def __init__(self, database_path: Path):
        self.database_path = database_path
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        self._bootstrap()

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.database_path)
        connection.row_factory = sqlite3.Row
        return connection

    def _bootstrap(self) -> None:
        with closing(self._connect()) as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS orders (
                    id TEXT PRIMARY KEY,
                    idempotency_key TEXT NOT NULL UNIQUE,
                    symbol TEXT NOT NULL,
                    side TEXT NOT NULL,
                    price REAL NOT NULL,
                    amount REAL NOT NULL,
                    timestamp REAL NOT NULL,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );

                CREATE TABLE IF NOT EXISTS commands (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    command TEXT NOT NULL,
                    consumed INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );

                CREATE TABLE IF NOT EXISTS outbox_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    aggregate_type TEXT NOT NULL,
                    aggregate_id TEXT NOT NULL,
                    idempotency_key TEXT NOT NULL,
                    topic TEXT NOT NULL,
                    payload TEXT NOT NULL,
                    status TEXT NOT NULL DEFAULT 'pending',
                    attempts INTEGER NOT NULL DEFAULT 0,
                    next_attempt_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    last_error TEXT,
                    locked_at TEXT,
                    delivered_at TEXT,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(idempotency_key, topic)
                );

                CREATE INDEX IF NOT EXISTS idx_outbox_ready
                ON outbox_events(status, next_attempt_at, id);

                CREATE TABLE IF NOT EXISTS relay_audit (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    event_id INTEGER,
                    action TEXT NOT NULL,
                    topic TEXT NOT NULL,
                    status TEXT NOT NULL,
                    detail TEXT,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );

                CREATE INDEX IF NOT EXISTS idx_relay_audit_created
                ON relay_audit(created_at, id);

                CREATE TABLE IF NOT EXISTS metrics_snapshots (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    bucket_start TEXT NOT NULL UNIQUE,
                    connected_dependencies INTEGER NOT NULL DEFAULT 0,
                    total_dependencies INTEGER NOT NULL DEFAULT 0,
                    outbox_due INTEGER NOT NULL DEFAULT 0,
                    outbox_failed INTEGER NOT NULL DEFAULT 0,
                    outbox_dead_letter INTEGER NOT NULL DEFAULT 0,
                    relay_sent INTEGER NOT NULL DEFAULT 0,
                    relay_dead_letter INTEGER NOT NULL DEFAULT 0,
                    relay_replay INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );
                """
            )
            connection.commit()

    def record_order(self, payload: dict[str, Any], idempotency_key: str, topic: str) -> bool:
        outbox_payload = json.dumps(
            {"order": payload, "idempotency_key": idempotency_key},
            separators=(",", ":"),
        )
        with closing(self._connect()) as connection:
            connection.execute("BEGIN IMMEDIATE")
            cursor = connection.execute(
                """
                INSERT OR IGNORE INTO orders (
                    id, idempotency_key, symbol, side, price, amount, timestamp
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
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
            if cursor.rowcount == 1:
                connection.execute(
                    """
                    INSERT OR IGNORE INTO outbox_events (
                        aggregate_type,
                        aggregate_id,
                        idempotency_key,
                        topic,
                        payload
                    ) VALUES (?, ?, ?, ?, ?)
                    """,
                    ("order", payload["id"], idempotency_key, topic, outbox_payload),
                )
            connection.commit()
            return cursor.rowcount == 1

    def enqueue_command(self, command: str) -> int:
        with closing(self._connect()) as connection:
            cursor = connection.execute(
                "INSERT INTO commands (command) VALUES (?)",
                (command,),
            )
            connection.commit()
            return int(cursor.lastrowid)

    def next_command(self) -> str | None:
        with closing(self._connect()) as connection:
            row = connection.execute(
                """
                SELECT id, command
                FROM commands
                WHERE consumed = 0
                ORDER BY id ASC
                LIMIT 1
                """
            ).fetchone()
            if row is None:
                return None
            connection.execute(
                "UPDATE commands SET consumed = 1 WHERE id = ?",
                (row["id"],),
            )
            connection.commit()
            return str(row["command"])

    def database_exists(self) -> bool:
        return self.database_path.exists()

    def claim_outbox_batch(self, limit: int) -> list[dict[str, Any]]:
        with closing(self._connect()) as connection:
            connection.execute("BEGIN IMMEDIATE")
            rows = connection.execute(
                """
                SELECT *
                FROM outbox_events
                WHERE status IN ('pending', 'failed')
                  AND next_attempt_at <= CURRENT_TIMESTAMP
                ORDER BY id ASC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
            ids = [int(row["id"]) for row in rows]
            if ids:
                placeholders = ", ".join("?" for _ in ids)
                connection.execute(
                    f"""
                    UPDATE outbox_events
                    SET status = 'processing',
                        attempts = attempts + 1,
                        locked_at = CURRENT_TIMESTAMP
                    WHERE id IN ({placeholders})
                    """,
                    ids,
                )
            connection.commit()
        claimed = [dict(row) for row in rows]
        for row in claimed:
            row["attempts"] = int(row["attempts"]) + 1
        return claimed

    def mark_outbox_sent(self, event_id: int) -> None:
        with closing(self._connect()) as connection:
            connection.execute(
                """
                UPDATE outbox_events
                SET status = 'sent',
                    locked_at = NULL,
                    last_error = NULL,
                    delivered_at = CURRENT_TIMESTAMP
                WHERE id = ?
                """,
                (event_id,),
            )
            connection.commit()

    def mark_outbox_failed(
        self,
        event_id: int,
        error: str,
        retry_delay_seconds: int,
        max_attempts: int,
        attempt_number: int,
    ) -> str:
        next_attempt = datetime.now(UTC) + timedelta(seconds=retry_delay_seconds)
        next_status = "dead_letter" if attempt_number >= max_attempts else "failed"
        next_attempt_at = (
            datetime.now(UTC).strftime("%Y-%m-%d %H:%M:%S")
            if next_status == "dead_letter"
            else next_attempt.strftime("%Y-%m-%d %H:%M:%S")
        )
        with closing(self._connect()) as connection:
            connection.execute(
                """
                UPDATE outbox_events
                SET status = ?,
                    locked_at = NULL,
                    last_error = ?,
                    next_attempt_at = ?
                WHERE id = ?
                """,
                (next_status, error[:500], next_attempt_at, event_id),
            )
            connection.commit()
        return next_status

    def outbox_stats(self) -> dict[str, int]:
        counters = {
            "pending": 0,
            "processing": 0,
            "failed": 0,
            "dead_letter": 0,
            "sent": 0,
        }
        with closing(self._connect()) as connection:
            rows = connection.execute(
                """
                SELECT status, COUNT(*) AS total
                FROM outbox_events
                GROUP BY status
                """
            ).fetchall()
            for row in rows:
                counters[str(row["status"])] = int(row["total"])
            due = connection.execute(
                """
                SELECT COUNT(*) AS total
                FROM outbox_events
                WHERE status IN ('pending', 'failed')
                  AND next_attempt_at <= CURRENT_TIMESTAMP
                """
            ).fetchone()
        counters["due"] = int(due["total"]) if due else 0
        return counters

    def list_outbox_events(
        self,
        status: str | None = None,
        limit: int = 50,
        statuses: list[str] | None = None,
        topic: str | None = None,
    ) -> list[dict[str, Any]]:
        query = "SELECT * FROM outbox_events"
        params: list[Any] = []
        filters: list[str] = []
        normalized_statuses = list(statuses or [])
        if status and status not in normalized_statuses:
            normalized_statuses.append(status)
        if normalized_statuses:
            placeholders = ", ".join("?" for _ in normalized_statuses)
            filters.append(f"status IN ({placeholders})")
            params.extend(normalized_statuses)
        if topic:
            filters.append("topic = ?")
            params.append(topic)
        if filters:
            query += " WHERE " + " AND ".join(filters)
        query += " ORDER BY id DESC LIMIT ?"
        params.append(limit)
        with closing(self._connect()) as connection:
            rows = connection.execute(query, tuple(params)).fetchall()
        return [dict(row) for row in rows]

    def fetch_outbox_event(self, event_id: int) -> dict[str, Any] | None:
        with closing(self._connect()) as connection:
            row = connection.execute(
                "SELECT * FROM outbox_events WHERE id = ?",
                (event_id,),
            ).fetchone()
        return dict(row) if row else None

    def replay_dead_letter_candidates(self, limit: int = 25) -> list[dict[str, Any]]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                """
                SELECT *
                FROM outbox_events
                WHERE status = 'dead_letter'
                ORDER BY id ASC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
        return [dict(row) for row in rows]

    def replay_outbox_event(self, event_id: int) -> bool:
        with closing(self._connect()) as connection:
            cursor = connection.execute(
                """
                UPDATE outbox_events
                SET status = 'pending',
                    attempts = 0,
                    next_attempt_at = CURRENT_TIMESTAMP,
                    last_error = NULL,
                    locked_at = NULL,
                    delivered_at = NULL
                WHERE id = ?
                  AND status IN ('failed', 'dead_letter', 'sent')
                """,
                (event_id,),
            )
            connection.commit()
            return cursor.rowcount == 1

    def replay_dead_letters(self, limit: int = 25) -> int:
        with closing(self._connect()) as connection:
            connection.execute("BEGIN IMMEDIATE")
            rows = connection.execute(
                """
                SELECT id
                FROM outbox_events
                WHERE status = 'dead_letter'
                ORDER BY id ASC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
            ids = [int(row["id"]) for row in rows]
            if ids:
                placeholders = ", ".join("?" for _ in ids)
                connection.execute(
                    f"""
                    UPDATE outbox_events
                    SET status = 'pending',
                        attempts = 0,
                        next_attempt_at = CURRENT_TIMESTAMP,
                        last_error = NULL,
                        locked_at = NULL,
                        delivered_at = NULL
                    WHERE id IN ({placeholders})
                    """,
                    ids,
                )
            connection.commit()
        return len(ids)

    def record_relay_audit(
        self,
        action: str,
        event_id: int | None,
        topic: str,
        status: str,
        detail: str | None = None,
    ) -> None:
        with closing(self._connect()) as connection:
            connection.execute(
                """
                INSERT INTO relay_audit (event_id, action, topic, status, detail)
                VALUES (?, ?, ?, ?, ?)
                """,
                (event_id, action, topic, status, (detail or "")[:500] or None),
            )
            connection.commit()

    def list_relay_audits(
        self,
        limit: int = 25,
        actions: list[str] | None = None,
        topics: list[str] | None = None,
        statuses: list[str] | None = None,
    ) -> list[dict[str, Any]]:
        query = "SELECT * FROM relay_audit"
        filters: list[str] = []
        params: list[Any] = []
        if actions:
            placeholders = ", ".join("?" for _ in actions)
            filters.append(f"action IN ({placeholders})")
            params.extend(actions)
        if topics:
            placeholders = ", ".join("?" for _ in topics)
            filters.append(f"topic IN ({placeholders})")
            params.extend(topics)
        if statuses:
            placeholders = ", ".join("?" for _ in statuses)
            filters.append(f"status IN ({placeholders})")
            params.extend(statuses)
        if filters:
            query += " WHERE " + " AND ".join(filters)
        query += " ORDER BY id DESC LIMIT ?"
        params.append(limit)
        with closing(self._connect()) as connection:
            rows = connection.execute(query, tuple(params)).fetchall()
        return [dict(row) for row in rows]

    def relay_audit_counts(self) -> dict[str, int]:
        counters = {"sent": 0, "dead_letter": 0, "replay": 0}
        with closing(self._connect()) as connection:
            rows = connection.execute(
                """
                SELECT action, COUNT(*) AS total
                FROM relay_audit
                GROUP BY action
                """
            ).fetchall()
        for row in rows:
            counters[str(row["action"])] = int(row["total"])
        return counters

    def list_topic_activity(self, limit: int = 12) -> list[dict[str, Any]]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                """
                SELECT
                    topic,
                    SUM(CASE WHEN action = 'sent' THEN 1 ELSE 0 END) AS sent_count,
                    SUM(CASE WHEN action = 'dead_letter' THEN 1 ELSE 0 END) AS dead_letter_count,
                    SUM(CASE WHEN action = 'replay' THEN 1 ELSE 0 END) AS replay_count,
                    MAX(created_at) AS last_seen_at
                FROM relay_audit
                GROUP BY topic
                ORDER BY MAX(created_at) DESC, topic ASC
                LIMIT ?
                """,
                (limit,),
            ).fetchall()
        return [dict(row) for row in rows]

    def record_metrics_snapshot(self, checks: dict[str, str] | None = None) -> None:
        checks = dict(checks or {})
        checks.setdefault(
            "sqlite",
            "connected" if self.database_exists() else "missing",
        )
        outbox = self.outbox_stats()
        audit = self.relay_audit_counts()
        bucket_start = datetime.now(UTC).strftime("%Y-%m-%d %H:%M:00")
        connected_dependencies = sum(1 for value in checks.values() if value == "connected")
        total_dependencies = len(checks)

        with closing(self._connect()) as connection:
            connection.execute(
                """
                INSERT INTO metrics_snapshots (
                    bucket_start,
                    connected_dependencies,
                    total_dependencies,
                    outbox_due,
                    outbox_failed,
                    outbox_dead_letter,
                    relay_sent,
                    relay_dead_letter,
                    relay_replay
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(bucket_start) DO UPDATE SET
                    connected_dependencies = excluded.connected_dependencies,
                    total_dependencies = excluded.total_dependencies,
                    outbox_due = excluded.outbox_due,
                    outbox_failed = excluded.outbox_failed,
                    outbox_dead_letter = excluded.outbox_dead_letter,
                    relay_sent = excluded.relay_sent,
                    relay_dead_letter = excluded.relay_dead_letter,
                    relay_replay = excluded.relay_replay
                """,
                (
                    bucket_start,
                    connected_dependencies,
                    total_dependencies,
                    outbox["due"],
                    outbox["failed"],
                    outbox["dead_letter"],
                    audit["sent"],
                    audit["dead_letter"],
                    audit["replay"],
                ),
            )
            connection.commit()

    def list_metrics_snapshots(self, limit: int = 24) -> list[dict[str, Any]]:
        with closing(self._connect()) as connection:
            rows = connection.execute(
                """
                SELECT *
                FROM (
                    SELECT *
                    FROM metrics_snapshots
                    ORDER BY bucket_start DESC
                    LIMIT ?
                )
                ORDER BY bucket_start ASC
                """,
                (limit,),
            ).fetchall()
        return [dict(row) for row in rows]

    def relay_metrics_snapshot(self) -> dict[str, float]:
        with closing(self._connect()) as connection:
            row = connection.execute(
                """
                SELECT
                    COUNT(*) AS total_events,
                    SUM(attempts) AS attempts_total,
                    SUM(CASE WHEN status = 'sent' THEN 1 ELSE 0 END) AS sent_total,
                    SUM(CASE WHEN status = 'dead_letter' THEN 1 ELSE 0 END) AS dead_letter_total,
                    SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_total,
                    MAX(
                        CASE
                            WHEN status IN ('pending', 'failed')
                            THEN CAST(strftime('%s','now') - strftime('%s', created_at) AS REAL)
                        END
                    ) AS oldest_retryable_age,
                    MAX(
                        CASE
                            WHEN status = 'dead_letter'
                            THEN CAST(strftime('%s','now') - strftime('%s', created_at) AS REAL)
                        END
                    ) AS oldest_dead_letter_age
                FROM outbox_events
                """
            ).fetchone()
        return {
            "total_events": float(row["total_events"] or 0),
            "attempts_total": float(row["attempts_total"] or 0),
            "sent_total": float(row["sent_total"] or 0),
            "dead_letter_total": float(row["dead_letter_total"] or 0),
            "failed_total": float(row["failed_total"] or 0),
            "oldest_retryable_age_seconds": float(row["oldest_retryable_age"] or 0),
            "oldest_dead_letter_age_seconds": float(row["oldest_dead_letter_age"] or 0),
        }

    def order_count(self) -> int:
        with closing(self._connect()) as connection:
            row = connection.execute("SELECT COUNT(*) AS total FROM orders").fetchone()
        return int(row["total"]) if row else 0

    def pending_command_count(self) -> int:
        with closing(self._connect()) as connection:
            row = connection.execute(
                "SELECT COUNT(*) AS total FROM commands WHERE consumed = 0"
            ).fetchone()
        return int(row["total"]) if row else 0
