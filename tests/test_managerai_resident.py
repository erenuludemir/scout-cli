from __future__ import annotations

import importlib
import json
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def test_resident_state_roundtrip(tmp_path, monkeypatch):
    base = tmp_path / "repo"
    monkeypatch.setenv("MANAGERAI_BASE_DIR", str(base))
    monkeypatch.setenv("MANAGERAI_STATE_DIR", str(base / "_state" / "managerai"))
    monkeypatch.setenv("MANAGERAI_REPORT_DIR", str(base / "_reports" / "managerai"))
    monkeypatch.setenv("MANAGERAI_LOG_DIR", str(base / "_logs" / "managerai"))
    monkeypatch.setenv("MANAGERAI_BROKER_QUEUE_DIR", str(base / "_state" / "managerai" / "queue"))

    state_mod = importlib.import_module("managerai.state")
    state_mod = importlib.reload(state_mod)

    state = state_mod.ResidentState.from_disk()
    state.cycle = 3
    state.last_diagnose_status = "ok"
    state.save()
    state.heartbeat({"probe": True})

    stored = json.loads(state_mod.STATE_FILE.read_text(encoding="utf-8"))
    heartbeat = json.loads(state_mod.HEARTBEAT_FILE.read_text(encoding="utf-8"))

    assert stored["cycle"] == 3
    assert stored["last_diagnose_status"] == "ok"
    assert heartbeat["probe"] is True


def test_emit_report_persists_files(tmp_path, monkeypatch):
    base = tmp_path / "repo"
    monkeypatch.setenv("MANAGERAI_BASE_DIR", str(base))
    monkeypatch.setenv("MANAGERAI_STATE_DIR", str(base / "_state" / "managerai"))
    monkeypatch.setenv("MANAGERAI_REPORT_DIR", str(base / "_reports" / "managerai"))
    monkeypatch.setenv("MANAGERAI_LOG_DIR", str(base / "_logs" / "managerai"))
    monkeypatch.setenv("MANAGERAI_BROKER_QUEUE_DIR", str(base / "_state" / "managerai" / "queue"))
    monkeypatch.setenv("MANAGERAI_BROKER_URL", "")

    importlib.reload(importlib.import_module("managerai.state"))
    reporter = importlib.import_module("managerai.reporter")
    reporter = importlib.reload(reporter)

    result = reporter.emit_report(
        "diagnose",
        {
            "status": "ok",
            "service_count": 1,
            "services": [
                {
                    "service": "gateway",
                    "status": "ok",
                    "quantum_score": 99,
                    "risk_level": "low",
                    "recommended_action": "observe",
                }
            ],
        },
    )

    assert result["ok"] is True
    assert result["broker"]["ok"] is False
    paths = result["paths"]
    assert Path(paths["markdown_path"]).exists()
    assert Path(paths["json_path"]).exists()

    last_report_path = base / "_state" / "managerai" / "last_report.json"
    assert last_report_path.exists()
    payload = json.loads(last_report_path.read_text(encoding="utf-8"))
    assert payload["kind"] == "diagnose"
