from __future__ import annotations

import importlib
from pathlib import Path
import sys

from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))


def configure_managerai_env(tmp_path, monkeypatch) -> None:
    base = tmp_path / "repo"
    monkeypatch.setenv("MANAGERAI_BASE_DIR", str(base))
    monkeypatch.setenv("MANAGERAI_STATE_DIR", str(base / "_state" / "managerai"))
    monkeypatch.setenv("MANAGERAI_REPORT_DIR", str(base / "_reports" / "managerai"))
    monkeypatch.setenv("MANAGERAI_LOG_DIR", str(base / "_logs" / "managerai"))
    monkeypatch.setenv("MANAGERAI_BROKER_QUEUE_DIR", str(base / "_state" / "managerai" / "queue"))
    importlib.reload(importlib.import_module("managerai.state"))


def test_managerai_healthz_endpoint(tmp_path, monkeypatch):
    configure_managerai_env(tmp_path, monkeypatch)
    module = importlib.reload(importlib.import_module("managerai.app"))

    assert module.healthz() == {"ok": True, "service": "managerai"}


def test_managerai_embedded_broker_routes(tmp_path, monkeypatch):
    configure_managerai_env(tmp_path, monkeypatch)
    module = importlib.reload(importlib.import_module("managerai.app"))

    published = module.publish(module.PublishRequest(topic="managerai.test", payload={"status": "ok"}))
    latest = module.topics_latest()
    events = module.topic_events("managerai.test", limit=20)

    assert published["status"] == "ok"
    assert latest["latest"]["topic"] == "managerai.test"
    assert events["events"][-1]["payload"] == {"status": "ok"}


def test_managerai_broker_healthz_endpoint(tmp_path, monkeypatch):
    configure_managerai_env(tmp_path, monkeypatch)
    module = importlib.reload(importlib.import_module("managerai.broker"))

    assert module.healthz() == {"status": "ok", "service": "managerai-broker"}


def test_managerai_broker_reads_only_bounded_event_tail(tmp_path, monkeypatch):
    configure_managerai_env(tmp_path, monkeypatch)
    module = importlib.reload(importlib.import_module("managerai.broker"))
    for event_id in range(6):
        module.publish(module.PublishRequest(topic="managerai.tail", payload={"id": event_id}))

    topic_path = module._topic_file("managerai.tail")
    with topic_path.open("a", encoding="utf-8") as handle:
        handle.write("not-json\n")

    original_read_text = Path.read_text

    def reject_topic_read_text(path, *args, **kwargs):
        if path == topic_path:
            raise AssertionError("topic history must be streamed")
        return original_read_text(path, *args, **kwargs)

    monkeypatch.setattr(Path, "read_text", reject_topic_read_text)

    payload = module.topic_events("managerai.tail", limit=3)

    assert [event["payload"]["id"] for event in payload["events"]] == [3, 4, 5]


def test_managerai_http_contract_exposes_panel_and_broker_routes(tmp_path, monkeypatch):
    configure_managerai_env(tmp_path, monkeypatch)
    module = importlib.reload(importlib.import_module("managerai.app"))
    monkeypatch.setattr(module, "current_catalog", lambda: [])
    monkeypatch.setattr(module.supervisor, "load_history_events", lambda limit: [])

    client = TestClient(module.app)
    expected_routes = {
        "/",
        "/health",
        "/healthz",
        "/publish",
        "/topics",
        "/topics/latest",
        "/topics/{topic_name}",
        "/api/services",
        "/api/overview",
        "/api/diagnose",
        "/api/autopilot",
        "/api/rolling-restart",
        "/api/history",
        "/api/resident",
    }

    assert expected_routes <= {route.path for route in module.app.routes}
    assert client.get("/").status_code == 200
    assert "ManagerAI" in client.get("/").text
    assert client.get("/health").status_code == 200
    assert client.get("/api/services").json()["service_count"] == 0
    assert client.get("/api/overview").json()["service_count"] == 0
    assert client.get("/api/history").json()["events"] == []
    assert client.get("/api/resident").status_code == 200

    published = client.post(
        "/publish",
        json={"topic": "managerai.http", "payload": {"status": "ok"}},
    )
    assert published.status_code == 200
    assert client.get("/topics/latest").json()["latest"]["topic"] == "managerai.http"


def test_managerai_http_diagnose_rejects_unknown_service(tmp_path, monkeypatch):
    configure_managerai_env(tmp_path, monkeypatch)
    module = importlib.reload(importlib.import_module("managerai.app"))
    monkeypatch.setattr(module, "current_catalog", lambda: [])

    response = TestClient(module.app).get("/api/diagnose", params={"service": "missing"})

    assert response.status_code == 404
    assert response.json()["detail"] == "unknown service: missing"
