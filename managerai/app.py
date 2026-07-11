from __future__ import annotations

import sys
from dataclasses import asdict
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

from orchestrator import supervizor_runtime as supervisor
from managerai.broker import (
    PublishRequest,
    latest as broker_latest,
    publish as broker_publish,
    topic_events as broker_topic_events,
    topics as broker_topics,
)
from managerai.state import (
    BROKER_QUEUE_DIR,
    HEARTBEAT_FILE,
    LAST_REPORT_FILE,
    REPORT_DIR,
    STATE_FILE,
    load_json,
)

sys.path.append("/app")
sys.path.append("/app/managerai")

app = FastAPI(title="ManagerAI")
STATIC_DIR = Path(__file__).resolve().parent / "static"
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")

try:
    from prometheus_fastapi_instrumentator import Instrumentator

    Instrumentator().instrument(app).expose(app)
except ImportError:
    print("Prometheus kütüphanesi henüz yüklenmedi...")


class RollingRestartRequest(BaseModel):
    service: str = Field(min_length=1)
    delay_secs: float = Field(default=2.0, ge=0.0, le=60.0)
    dry_run: bool = False


class AutopilotRequest(BaseModel):
    apply: bool = False
    service: str | None = Field(default=None, min_length=1)


def current_catalog() -> list[supervisor.ServiceRecord]:
    try:
        return supervisor.load_catalog(supervisor.configured_compose_files())
    except Exception:
        return []


def resident_payload() -> dict[str, Any]:
    reports: list[dict[str, Any]] = []
    for path in sorted(REPORT_DIR.glob("*.json"), reverse=True)[:5]:
        report = load_json(path, {})
        if isinstance(report, dict):
            reports.append(
                {
                    "name": path.name,
                    "kind": report.get("kind", path.stem.split("_", 1)[0]),
                    "status": report.get("status", "unknown"),
                }
            )
    return {
        "resident_state": load_json(STATE_FILE, {}),
        "heartbeat": load_json(HEARTBEAT_FILE, {}),
        "last_report": load_json(LAST_REPORT_FILE, {}),
        "broker_latest": load_json(BROKER_QUEUE_DIR / "topics" / "latest.json", {}),
        "reports": reports,
    }


@app.get("/", include_in_schema=False)
def panel() -> FileResponse:
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/healthz")
def healthz() -> dict[str, Any]:
    return {"ok": True, "service": "managerai"}


@app.post("/publish")
def publish(req: PublishRequest) -> dict[str, Any]:
    return broker_publish(req)


@app.get("/topics")
def topics(limit: int = Query(default=50, ge=1, le=500)) -> dict[str, Any]:
    return broker_topics(limit=limit)


@app.get("/topics/latest")
def topics_latest() -> dict[str, Any]:
    return broker_latest()


@app.get("/topics/{topic_name}")
def topic_events(
    topic_name: str,
    limit: int = Query(default=20, ge=1, le=200),
) -> dict[str, Any]:
    return broker_topic_events(topic_name, limit=limit)


@app.get("/health")
def health() -> dict[str, Any]:
    payload = resident_payload()
    resident_state = payload.get("resident_state") or {}
    last_report = payload.get("last_report") or {}
    broker_latest = payload.get("broker_latest") or {}
    last_report_status = str(last_report.get("status") or "").strip().lower()
    broker_status = str((broker_latest.get("payload") or {}).get("status") or "").strip().lower()
    resident_status = "ok"
    if last_report_status == "degraded" or broker_status == "degraded":
        resident_status = "degraded"
    elif resident_state.get("last_diagnose_status") == "degraded" and last_report_status != "ok" and broker_status != "ok":
        resident_status = "degraded"
    return {
        "status": "ok",
        "resident_status": resident_status,
        "resident_state": resident_state,
        "last_report": last_report,
        "broker_latest": broker_latest,
    }


def diagnose_payload(
    *,
    service: str | None,
    log_lines: int = 120,
    cooldown_secs: int = 900,
    record_event: bool = False,
) -> dict[str, Any]:
    catalog = current_catalog()
    if service is not None:
        catalog = [item for item in catalog if item.service == service]
        if not catalog:
            raise HTTPException(status_code=404, detail=f"unknown service: {service}")

    services = [
        supervisor.diagnose_service(
            record,
            log_lines=log_lines,
            cooldown_secs=cooldown_secs,
        )
        for record in catalog
    ]
    status = supervisor.overall_health_status(services)
    payload = {
        "status": status,
        "service_count": len(services),
        "generated_at": supervisor.utcnow_iso(),
        "log_lines": log_lines,
        "cooldown_secs": cooldown_secs,
        "services": services,
    }
    if record_event:
        supervisor.append_history(
            {
                "kind": "diagnose",
                "timestamp": payload["generated_at"],
                "service": service,
                "status": status,
                "services": [
                    {
                        "service": item["service"],
                        "status": item["status"],
                        "quantum_score": item["quantum_score"],
                        "recommended_action": item["recommended_action"],
                    }
                    for item in services
                ],
            }
        )
    return payload


@app.get("/api/diagnose")
def api_diagnose(
    service: str | None = None,
    log_lines: int = Query(default=120, ge=1, le=2000),
    cooldown_secs: int = Query(default=900, ge=0, le=86400),
) -> dict[str, Any]:
    return diagnose_payload(
        service=service,
        log_lines=log_lines,
        cooldown_secs=cooldown_secs,
        record_event=True,
    )


def rolling_restart_payload(request: RollingRestartRequest) -> dict[str, Any]:
    record = next((item for item in current_catalog() if item.service == request.service), None)
    if record is None:
        raise HTTPException(status_code=404, detail=f"unknown service: {request.service}")

    supervisor.ensure_restart_prereqs()
    containers = supervisor.discover_containers(record)
    restarted = supervisor.restart_service(record, delay_secs=request.delay_secs, dry_run=request.dry_run)
    payload = {
        "status": "ok",
        "mode": "rolling-restart",
        "service": request.service,
        "delay_secs": request.delay_secs,
        "dry_run": request.dry_run,
        "actions": [
            {
                "service": request.service,
                "container_name": record.container_name or request.service,
                "restarted": restarted or containers,
            }
        ],
    }
    supervisor.append_history(payload)
    return payload


@app.post("/api/rolling-restart")
def api_rolling_restart(request: RollingRestartRequest) -> dict[str, Any]:
    return rolling_restart_payload(request)


@app.post("/api/autopilot")
def api_autopilot(request: AutopilotRequest) -> dict[str, Any]:
    from managerai import guard

    try:
        return guard.autopilot(apply=request.apply, service=request.service)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@app.get("/api/services")
def api_services() -> dict[str, Any]:
    catalog = current_catalog()
    return {
        "status": "ok",
        "service_count": len(catalog),
        "services": [asdict(record) for record in catalog],
    }


@app.get("/api/history")
def api_history(limit: int = Query(default=20, ge=1, le=500)) -> dict[str, Any]:
    events = supervisor.load_history_events(limit=limit)
    return {
        "status": "ok",
        "event_count": len(events),
        "events": events,
    }


@app.get("/api/resident")
def api_resident() -> dict[str, Any]:
    return resident_payload()


@app.get("/api/overview")
def api_overview(service: str | None=None) -> dict[str, Any]:
    catalog = current_catalog()
    if service is not None:
        catalog = [item for item in catalog if item.service == service]

    services: list[dict[str, Any]] = []
    for record in catalog:
        try:
            health_report = supervisor.service_health(record)
        except Exception:
            health_report = {"status": "unknown", "service": record.service}
        status = str(health_report.get("status", "unknown"))
        healthy = status in {"ok", "healthy", "running"}
        recommended_action = "observe" if healthy else "restart"
        services.append(
            {
                "service": record.service,
                "container_name": record.container_name,
                "compose_file": record.compose_file,
                "has_healthcheck": record.has_healthcheck,
                "healthcheck_target_path": record.healthcheck_target_path,
                "status": status,
                "risk_level": "low" if healthy else "high",
                "quantum_score": 100 if healthy else 0,
                "container_count": int(health_report.get("container_count", 0)),
                "signal_totals": {},
                "reasons": [],
                "recommendation_confidence": 1.0,
                "cooldown_remaining_secs": 0,
                "recommended_action": recommended_action,
                "stats": [],
            }
        )
    return {
        "status": supervisor.overall_health_status(services),
        "generated_at": supervisor.utcnow_iso(),
        "service_count": len(services),
        "services": services,
    }
