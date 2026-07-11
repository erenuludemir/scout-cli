from __future__ import annotations

import importlib
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def load_guard(tmp_path, monkeypatch):
    base = tmp_path / "repo"
    monkeypatch.setenv("MANAGERAI_BASE_DIR", str(base))
    monkeypatch.setenv("MANAGERAI_STATE_DIR", str(base / "_state" / "managerai"))
    monkeypatch.setenv("MANAGERAI_REPORT_DIR", str(base / "_reports" / "managerai"))
    monkeypatch.setenv("MANAGERAI_LOG_DIR", str(base / "_logs" / "managerai"))
    monkeypatch.setenv("MANAGERAI_BROKER_QUEUE_DIR", str(base / "_state" / "managerai" / "queue"))
    monkeypatch.setenv("MANAGERAI_REPO_ROOT", str(base))
    monkeypatch.setenv("MANAGERAI_EXCLUDE_SERVICES", "managerai-broker,managerai-guard")
    importlib.reload(importlib.import_module("managerai.state"))
    module = importlib.import_module("managerai.guard")
    return importlib.reload(module)


def test_filtered_payload_excludes_guard_services_and_actions(tmp_path, monkeypatch):
    guard = load_guard(tmp_path, monkeypatch)

    payload = guard.filtered_payload(
        {
            "status": "degraded",
            "service_count": 3,
            "services": [
                {"service": "managerai-broker", "status": "ok"},
                {"service": "managerai-guard", "status": "degraded"},
                {"service": "gateway", "status": "ok"},
            ],
            "actions": [
                {"service": "managerai-broker", "decision": "restart"},
                {"service": "gateway", "decision": "observe"},
            ],
        }
    )

    assert payload["service_count"] == 1
    assert [item["service"] for item in payload["services"]] == ["gateway"]
    assert [item["service"] for item in payload["actions"]] == ["gateway"]
    assert payload["status"] == "ok"


def test_choose_apply_only_for_actionable_risk(tmp_path, monkeypatch):
    guard = load_guard(tmp_path, monkeypatch)
    monkeypatch.setattr(guard, "APPLY_ON_CRITICAL", True)
    monkeypatch.setattr(guard, "APPLY_ON_HIGH", False)

    assert (
        guard.choose_apply(
            {
                "services": [
                    {"risk_level": "critical", "recommended_action": "restart"},
                ]
            }
        )
        is True
    )
    assert (
        guard.choose_apply(
            {
                "services": [
                    {"risk_level": "high", "recommended_action": "restart"},
                ]
            }
        )
        is False
    )


def test_autopilot_passes_service_filter_to_supervisor(tmp_path, monkeypatch):
    guard = load_guard(tmp_path, monkeypatch)
    captured = {}

    def capture_command(args):
        captured["args"] = args
        return {"status": "ok", "actions": []}

    monkeypatch.setattr(guard, "run_cmd", capture_command)

    payload = guard.autopilot(apply=False, service="gateway")

    assert payload["status"] == "ok"
    assert captured["args"][-2:] == ["--service", "gateway"]
    assert (
        guard.choose_apply(
            {
                "services": [
                    {"risk_level": "critical", "recommended_action": "observe"},
                ]
            }
        )
        is False
    )
