from __future__ import annotations

import importlib
from pathlib import Path
import sys

from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from orchestrator.supervizor_runtime import ServiceRecord  # noqa: E402


def load_managerai_app(tmp_path, monkeypatch):
    base = tmp_path / "repo"
    monkeypatch.setenv("MANAGERAI_BASE_DIR", str(base))
    monkeypatch.setenv("MANAGERAI_STATE_DIR", str(base / "_state" / "managerai"))
    monkeypatch.setenv("MANAGERAI_REPORT_DIR", str(base / "_reports" / "managerai"))
    monkeypatch.setenv("MANAGERAI_LOG_DIR", str(base / "_logs" / "managerai"))
    monkeypatch.setenv("MANAGERAI_BROKER_QUEUE_DIR", str(base / "_state" / "managerai" / "queue"))

    importlib.reload(importlib.import_module("managerai.state"))
    module = importlib.import_module("managerai.app")
    return importlib.reload(module)


def test_health_uses_latest_report_status(tmp_path, monkeypatch):
    managerai_app = load_managerai_app(tmp_path, monkeypatch)
    monkeypatch.setattr(managerai_app, "current_catalog", lambda: [])
    monkeypatch.setattr(
        managerai_app,
        "resident_payload",
        lambda: {
            "resident_state": {"cycle": 4, "last_diagnose_status": "degraded"},
            "last_report": {"status": "ok"},
            "broker_latest": {"payload": {"status": "ok"}},
        },
    )

    payload = managerai_app.health()
    assert payload["resident_status"] == "ok"


def test_manual_rolling_restart_payload(tmp_path, monkeypatch):
    managerai_app = load_managerai_app(tmp_path, monkeypatch)
    record = ServiceRecord(
        service="gateway",
        container_name="gateway",
        compose_file="/repo/compose.yml",
        has_healthcheck=True,
    )

    monkeypatch.setattr(managerai_app, "current_catalog", lambda: [record])
    monkeypatch.setattr(managerai_app.supervisor, "ensure_restart_prereqs", lambda: None)
    monkeypatch.setattr(managerai_app.supervisor, "discover_containers", lambda _record: ["gateway-1"])
    monkeypatch.setattr(
        managerai_app.supervisor,
        "restart_service",
        lambda _record, delay_secs, dry_run: ["gateway-1"],
    )
    monkeypatch.setattr(managerai_app.supervisor, "append_history", lambda payload: None)

    payload = managerai_app.rolling_restart_payload(
        managerai_app.RollingRestartRequest(service="gateway", delay_secs=1.5, dry_run=False)
    )
    assert payload["status"] == "ok"
    assert payload["mode"] == "rolling-restart"
    assert payload["actions"][0]["service"] == "gateway"
    assert payload["actions"][0]["restarted"] == ["gateway-1"]


def test_overview_without_filter_uses_summary_payload(tmp_path, monkeypatch):
    managerai_app = load_managerai_app(tmp_path, monkeypatch)
    record = ServiceRecord(
        service="metrics",
        container_name="metrics",
        compose_file="/repo/compose.yml",
        has_healthcheck=True,
    )

    monkeypatch.setattr(managerai_app, "current_catalog", lambda: [record])
    monkeypatch.setattr(
        managerai_app.supervisor,
        "service_health",
        lambda _record: {
            "service": "metrics",
            "status": "ok",
            "compose_file": "/repo/compose.yml",
            "containers": [{"container": "metrics", "status": "running", "running": True}],
            "container_count": 1,
            "has_healthcheck": True,
        },
    )
    monkeypatch.setattr(managerai_app.supervisor, "latest_applied_action", lambda _service: None)

    payload = managerai_app.api_overview(service=None)

    assert payload["status"] == "ok"
    assert payload["service_count"] == 1
    assert payload["services"][0]["service"] == "metrics"
    assert payload["services"][0]["recommended_action"] == "observe"
    assert payload["services"][0]["stats"] == []


def test_http_rolling_restart_returns_404_for_unknown_service(tmp_path, monkeypatch):
    managerai_app = load_managerai_app(tmp_path, monkeypatch)
    monkeypatch.setattr(managerai_app, "current_catalog", lambda: [])

    response = TestClient(managerai_app.app).post(
        "/api/rolling-restart",
        json={"service": "missing", "delay_secs": 1.0, "dry_run": True},
    )

    assert response.status_code == 404
    assert response.json()["detail"] == "unknown service: missing"
