from __future__ import annotations

import importlib

import pytest
from fastapi import HTTPException

from orchestrator import supervizor_runtime as supervisor


def test_diagnose_payload_returns_404_for_unknown_service(tmp_path, monkeypatch):
    base = tmp_path / "repo"
    monkeypatch.setenv("MANAGERAI_BASE_DIR", str(base))
    monkeypatch.setenv("MANAGERAI_STATE_DIR", str(base / "_state" / "managerai"))
    monkeypatch.setenv("MANAGERAI_REPORT_DIR", str(base / "_reports" / "managerai"))
    monkeypatch.setenv("MANAGERAI_LOG_DIR", str(base / "_logs" / "managerai"))
    monkeypatch.setenv("MANAGERAI_BROKER_QUEUE_DIR", str(base / "_state" / "managerai" / "queue"))

    manager_app = importlib.import_module("managerai.app")
    manager_app = importlib.reload(manager_app)

    catalog = [
        supervisor.ServiceRecord(
            service="gateway",
            container_name="gateway-1",
            compose_file="/tmp/compose.yml",
            has_healthcheck=True,
            healthcheck_target="http://127.0.0.1:8080/health",
            healthcheck_target_path="/health",
        )
    ]
    monkeypatch.setattr(manager_app, "current_catalog", lambda: catalog)

    with pytest.raises(HTTPException) as exc_info:
        manager_app.diagnose_payload(
            service="mcai-api",
            log_lines=120,
            cooldown_secs=900,
            record_event=False,
        )

    assert exc_info.value.status_code == 404
    assert exc_info.value.detail == "unknown service: mcai-api"
