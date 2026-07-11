from __future__ import annotations

from datetime import datetime, UTC
from typing import Any

from fastapi import FastAPI, Header, HTTPException, Query, Response, status
from fastapi.responses import PlainTextResponse

from .config import RuntimeConfig
from .integrations import RuntimeIntegrations
from .metrics import RuntimeMetricsRenderer
from .models import CommandPayload, HealthResponse, OrderPayload
from .relay import EmbeddedRelayRunner, OutboxRelay
from .storage import RuntimeStore

config = RuntimeConfig.load()
store = RuntimeStore(config.database_path)
integrations = RuntimeIntegrations(config)
relay = OutboxRelay(store, integrations, config)
embedded_relay = EmbeddedRelayRunner(relay)
metrics = RuntimeMetricsRenderer(store, integrations)
app = FastAPI(title="QuantumAI Runtime API", version="0.1.0")


def build_checks() -> dict[str, str]:
    return {
        "sqlite": "connected" if store.database_exists() else "missing",
        **integrations.health_checks(),
    }


def record_replay(event: dict[str, object], replay_source: str) -> str:
    status = "published"
    detail = replay_source
    try:
        integrations.publish_replay_event(
            event,
            previous_status=str(event["status"]),
            replay_source=replay_source,
        )
    except Exception as exc:
        status = "publish_failed"
        detail = f"{replay_source} | kafka={str(exc)[:220]}"
    store.record_relay_audit(
        action="replay",
        event_id=int(event["id"]),
        topic=config.kafka_replay_topic,
        status=status,
        detail=detail,
    )
    store.record_metrics_snapshot(build_checks())
    return status


def parse_csv_terms(value: str | None) -> list[str]:
    if value is None:
        return []
    return [item.strip() for item in value.split(",") if item.strip()]


def drilldown_filters(metric: str) -> dict[str, list[str] | str | None]:
    normalized = metric.strip().lower()
    if normalized == "queue":
        return {
            "actions": ["dead_letter", "replay"],
            "topics": [config.kafka_dead_letter_topic, config.kafka_replay_topic],
            "statuses": ["published", "publish_failed"],
            "event_statuses": ["pending", "failed", "dead_letter"],
            "event_topic": config.kafka_orders_topic,
        }
    if normalized == "relay":
        return {
            "actions": ["sent"],
            "topics": [config.kafka_orders_topic],
            "statuses": ["published"],
            "event_statuses": ["sent"],
            "event_topic": config.kafka_orders_topic,
        }
    if normalized == "replay":
        return {
            "actions": ["replay"],
            "topics": [config.kafka_replay_topic],
            "statuses": ["published", "publish_failed"],
            "event_statuses": ["failed", "dead_letter", "sent"],
            "event_topic": config.kafka_orders_topic,
        }
    if normalized in {"deps", "dependencies"}:
        return {
            "actions": ["dead_letter", "replay"],
            "topics": [config.kafka_dead_letter_topic, config.kafka_replay_topic],
            "statuses": ["publish_failed", "published"],
            "event_statuses": ["failed", "dead_letter"],
            "event_topic": config.kafka_orders_topic,
        }
    raise HTTPException(status_code=422, detail=f"Unsupported drilldown metric: {metric}")


@app.on_event("startup")
def startup() -> None:
    integrations.bootstrap()
    store.record_metrics_snapshot(build_checks())
    if config.embedded_relay_enabled:
        embedded_relay.start()


@app.on_event("shutdown")
def shutdown() -> None:
    embedded_relay.stop()


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(
        status="ok",
        service="qai-runtime-api",
        timestamp=datetime.now(UTC),
        checks=build_checks(),
    )


@app.get("/ready", response_model=HealthResponse)
def ready() -> HealthResponse:
    checks = build_checks()
    blocking_checks = {
        name: value
        for name, value in checks.items()
        if value not in {"connected", "optional"}
    }
    status_text = "ready" if not blocking_checks else "degraded"
    return HealthResponse(
        status=status_text,
        service="qai-runtime-api",
        timestamp=datetime.now(UTC),
        checks=checks,
    )


@app.post("/api/orders")
def create_order(
    payload: OrderPayload,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
) -> dict[str, str]:
    key = idempotency_key or payload.id
    was_inserted = store.record_order(payload.model_dump(), key, config.kafka_orders_topic)
    return {
        "status": "accepted" if was_inserted else "duplicate",
        "idempotency_key": key,
    }


@app.post("/v1/commands", status_code=status.HTTP_202_ACCEPTED)
def enqueue_command(payload: CommandPayload) -> dict[str, int | str]:
    command_id = store.enqueue_command(payload.command)
    return {"status": "queued", "id": command_id}


@app.get("/v1/commands")
def pull_command(response: Response) -> dict[str, str]:
    command = store.next_command()
    if command is None:
        response.status_code = status.HTTP_204_NO_CONTENT
        return {}
    return {"command": command}


@app.get("/admin/outbox")
def outbox_status() -> dict[str, int]:
    return store.outbox_stats()


@app.get("/admin/runbook")
def runtime_runbook(
    limit: int = Query(default=12, ge=1, le=100),
    audit_action: str | None = Query(default=None),
    audit_topic: str | None = Query(default=None),
    audit_status: str | None = Query(default=None),
) -> dict[str, object]:
    actions = parse_csv_terms(audit_action) or None
    topics = parse_csv_terms(audit_topic) or None
    statuses = parse_csv_terms(audit_status) or None
    return {
        "service": "qai-runtime-api",
        "checks": build_checks(),
        "outbox": store.outbox_stats(),
        "topics": {
            "orders": config.kafka_orders_topic,
            "dead_letter": config.kafka_dead_letter_topic,
            "replay": config.kafka_replay_topic,
        },
        "filters": {
            "audit_actions": actions or [],
            "audit_topics": topics or [],
            "audit_statuses": statuses or [],
        },
        "audit_counts": store.relay_audit_counts(),
        "topic_activity": store.list_topic_activity(limit=min(limit, 12)),
        "trend_points": store.list_metrics_snapshots(limit=min(limit, 48)),
        "recent_audits": store.list_relay_audits(
            limit=limit,
            actions=actions,
            topics=topics,
            statuses=statuses,
        ),
    }


@app.get("/admin/runbook/drilldown")
def runtime_runbook_drilldown(
    metric: str = Query(...),
    limit: int = Query(default=8, ge=1, le=50),
) -> dict[str, Any]:
    filters = drilldown_filters(metric)
    actions = list(filters["actions"]) if filters["actions"] else None
    topics = list(filters["topics"]) if filters["topics"] else None
    statuses = list(filters["statuses"]) if filters["statuses"] else None
    event_statuses = list(filters["event_statuses"]) if filters["event_statuses"] else None
    event_topic = str(filters["event_topic"]) if filters["event_topic"] else None
    return {
        "metric": metric.lower(),
        "checks": build_checks(),
        "outbox": store.outbox_stats(),
        "recent_audits": store.list_relay_audits(
            limit=limit,
            actions=actions,
            topics=topics,
            statuses=statuses,
        ),
        "events": store.list_outbox_events(
            limit=limit,
            statuses=event_statuses,
            topic=event_topic,
        ),
    }


@app.get("/admin/outbox/events")
def outbox_events(
    event_status: str | None = Query(default=None, alias="status"),
    event_topic: str | None = Query(default=None, alias="topic"),
    limit: int = Query(default=25, ge=1, le=200),
) -> dict[str, object]:
    items = store.list_outbox_events(
        limit=limit,
        statuses=parse_csv_terms(event_status) or None,
        topic=event_topic,
    )
    return {
        "items": items,
        "count": len(items),
    }


@app.post("/admin/outbox/drain")
def drain_outbox() -> dict[str, int]:
    result = relay.drain_once()
    store.record_metrics_snapshot(build_checks())
    return {
        "claimed": result.claimed,
        "sent": result.sent,
        "failed": result.failed,
        "dead_lettered": result.dead_lettered,
    }


@app.post("/admin/outbox/replay/{event_id}")
def replay_outbox_event(event_id: int) -> dict[str, object]:
    event = store.fetch_outbox_event(event_id)
    replayed = store.replay_outbox_event(event_id)
    published = False
    if replayed and event is not None:
        published = record_replay(event, replay_source="admin.single") == "published"
    return {"replayed": replayed, "event_id": event_id, "published": published}


@app.post("/admin/outbox/replay-dead-letters")
def replay_dead_letters(limit: int = Query(default=25, ge=1, le=200)) -> dict[str, int]:
    candidates = store.replay_dead_letter_candidates(limit=limit)
    replayed = store.replay_dead_letters(limit=limit)
    published = 0
    for event in candidates[:replayed]:
        if record_replay(event, replay_source="admin.bulk") == "published":
            published += 1
    return {"replayed": replayed, "published": published}


@app.get("/metrics", response_class=PlainTextResponse)
def runtime_metrics() -> str:
    return metrics.render()


@app.get("/")
def root() -> dict[str, str]:
    return {"service": "qai-runtime-api", "docs": "/docs", "health": "/health"}
