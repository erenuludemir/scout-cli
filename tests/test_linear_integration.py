from __future__ import annotations

import json
from pathlib import Path

from app import create_app
from ai.signals.push_signal_to_linear import build_issue_description, build_issue_title, push_signal_to_linear
from integrations.linear.linear_client import LinearClient


class DummyResponse:
    def __init__(self, payload):
        self.payload = payload

    def raise_for_status(self):
        return None

    def json(self):
        return self.payload


def test_linear_client_health_and_issue_create(monkeypatch):
    calls = []

    def fake_post(url, headers, json, timeout):
        calls.append(json)
        query = json["query"]
        if "LinearViewerHealth" in query:
            return DummyResponse({"data": {"viewer": {"id": "viewer-1", "name": "QAI", "email": "qai@example.com", "active": True}}})
        if "LinearTeams" in query:
            return DummyResponse({"data": {"teams": {"nodes": [{"id": "team-1", "key": "ENG", "name": "Engineering"}]}}})
        if "LinearIssueCreate" in query:
            return DummyResponse(
                {
                    "data": {
                        "issueCreate": {
                            "success": True,
                            "issue": {
                                "id": "issue-1",
                                "identifier": "ENG-1",
                                "title": "AI Signal BTCUSDT: BUY (96.62%)",
                                "url": "https://linear.app/issue/ENG-1",
                                "state": {"id": "state-1", "name": "Backlog"},
                                "team": {"id": "team-1", "key": "ENG", "name": "Engineering"},
                            },
                        }
                    }
                }
            )
        raise AssertionError("unexpected query")

    monkeypatch.setattr("integrations.linear.linear_client.requests.post", fake_post)
    monkeypatch.setenv("LINEAR_API_KEY", "lin_api_test")

    client = LinearClient()
    assert client.health()["viewer"]["id"] == "viewer-1"
    issue = client.create_issue(title="AI Signal BTCUSDT: BUY (96.62%)", description="body", team_key="ENG")
    assert issue["identifier"] == "ENG-1"
    assert len(calls) == 3


def test_linear_flask_routes(monkeypatch):
    monkeypatch.setenv("LINEAR_API_KEY", "lin_api_test")
    monkeypatch.setattr(LinearClient, "health", lambda self: {"viewer": {"id": "viewer-1", "name": "QAI"}})
    monkeypatch.setattr(LinearClient, "list_teams", lambda self: [{"id": "team-1", "key": "ENG", "name": "Engineering"}])
    monkeypatch.setattr(
        LinearClient,
        "create_issue",
        lambda self, **kwargs: {"id": "issue-1", "identifier": "ENG-1", "title": kwargs["title"]},
    )

    app = create_app()
    client = app.test_client()

    response = client.get("/linear/health")
    assert response.status_code == 200
    assert response.get_json()["ok"] is True

    response = client.get("/linear/teams")
    assert response.status_code == 200
    assert response.get_json()["count"] == 1

    response = client.post("/linear/issues", json={"title": "Test issue", "description": "body", "team_key": "ENG"})
    assert response.status_code == 200
    assert response.get_json()["issue"]["identifier"] == "ENG-1"


def test_push_signal_to_linear_roundtrip(tmp_path, monkeypatch):
    signal_path = tmp_path / "signal.json"
    signal_path.write_text(
        json.dumps(
            {
                "symbol": "BTCUSDT",
                "interval": "1h",
                "signal": "BUY",
                "confidence": 0.9662,
                "price": 70000.0,
                "stop_loss": 69000.0,
                "take_profit": 72000.0,
                "reasons": ["trend_up"],
                "probabilities": {"SELL": 0.01, "HOLD": 0.02, "BUY": 0.97},
                "risk": {"mc_p10": 68000.0, "mc_p50": 70500.0, "mc_p90": 73000.0},
            }
        ),
        encoding="utf-8",
    )

    class FakeLinearClient:
        def __init__(self, *args, **kwargs):
            pass

        def create_issue(self, **kwargs):
            return {"id": "issue-1", "identifier": "ENG-7", "title": kwargs["title"]}

    monkeypatch.setenv("LINEAR_API_KEY", "lin_api_test")
    monkeypatch.setattr("ai.signals.push_signal_to_linear.LinearClient", FakeLinearClient)

    title = build_issue_title(json.loads(signal_path.read_text(encoding="utf-8")))
    description = build_issue_description(json.loads(signal_path.read_text(encoding="utf-8")))
    assert "BTCUSDT" in title
    assert "QuantumAI Signal Summary" in description

    result = push_signal_to_linear(root=tmp_path, signal_path=str(signal_path), team_key="ENG")
    assert result["ok"] is True
    assert result["issue"]["identifier"] == "ENG-7"
    assert (tmp_path / "ai" / "models" / "latest_linear_issue.json").exists()
