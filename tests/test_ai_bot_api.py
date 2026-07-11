from __future__ import annotations

import importlib
import subprocess

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient


def load_api(monkeypatch, *, timeout: str = "7"):
    monkeypatch.setenv("QAI_COMMAND_TIMEOUT_SECS", timeout)
    module = importlib.import_module("ai.api.ai_bot_api")
    return importlib.reload(module)


def test_ai_api_rejects_out_of_bounds_requests(monkeypatch):
    module = load_api(monkeypatch)
    client = TestClient(module.app)

    assert client.post("/dataset/build", json={"limit": 0}).status_code == 422
    assert client.post("/dataset/build", json={"symbol": "../BTC"}).status_code == 422
    assert client.post(
        "/strategy/grid-leverage",
        json={"account_equity": -1, "risk_pct": 0.01},
    ).status_code == 422
    assert client.post(
        "/strategy/grid-leverage",
        json={"account_equity": 10000, "risk_pct": 0.5},
    ).status_code == 422


def test_run_py_maps_timeout_to_gateway_timeout(monkeypatch, tmp_path):
    module = load_api(monkeypatch, timeout="3")
    script = tmp_path / "worker.py"
    script.write_text("", encoding="utf-8")

    def raise_timeout(*args, **kwargs):
        assert kwargs["timeout"] == 3
        raise subprocess.TimeoutExpired(args[0], timeout=kwargs["timeout"])

    monkeypatch.setattr(module.subprocess, "run", raise_timeout)

    with pytest.raises(HTTPException) as exc_info:
        module.run_py(script)

    assert exc_info.value.status_code == 504
    assert exc_info.value.detail["timeout_secs"] == 3


def test_run_py_bounds_nonzero_command_output(monkeypatch, tmp_path):
    module = load_api(monkeypatch)
    script = tmp_path / "worker.py"
    script.write_text("", encoding="utf-8")
    completed = subprocess.CompletedProcess(
        args=["python", str(script)],
        returncode=2,
        stdout="x" * 10000,
        stderr="y" * 10000,
    )
    monkeypatch.setattr(module.subprocess, "run", lambda *args, **kwargs: completed)

    with pytest.raises(HTTPException) as exc_info:
        module.run_py(script)

    assert exc_info.value.status_code == 500
    assert len(exc_info.value.detail["stderr"]) <= 4000
    assert len(exc_info.value.detail["stdout"]) <= 100
