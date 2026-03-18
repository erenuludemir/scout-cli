import importlib.util
import os
import sys


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:  # pragma: no cover
    sys.path.insert(0, ROOT)


def load_usdt_module():
    module_path = os.path.join(ROOT, "usdt", "app.py")
    spec = importlib.util.spec_from_file_location("qai_usdt_app", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_health_reports_preview_mode_without_live_wallet_config(monkeypatch):
    usdt_app = load_usdt_module()
    for key in ("INFURA_URL", "INFURA_PROJECT_ID", "ETH_SENDER_ADDRESS", "ETH_PRIVATE_KEY"):
        monkeypatch.delenv(key, raising=False)
    monkeypatch.setenv("GLI_DRY_RUN", "1")

    client = usdt_app.create_app().test_client()
    response = client.get("/health")

    assert response.status_code == 200
    data = response.get_json()
    assert data["ok"] is True
    assert data["service"] == "usdt"
    assert data["mode"] == "preview"
    assert data["execution_enabled"] is False
    assert "INFURA_URL/INFURA_PROJECT_ID missing or placeholder" in data["configuration_errors"]


def test_transfer_returns_clear_preview_mode_error_when_runtime_missing(monkeypatch):
    usdt_app = load_usdt_module()
    for key in ("INFURA_URL", "INFURA_PROJECT_ID", "ETH_SENDER_ADDRESS", "ETH_PRIVATE_KEY"):
        monkeypatch.delenv(key, raising=False)
    monkeypatch.setenv("GLI_DRY_RUN", "1")

    client = usdt_app.create_app().test_client()
    response = client.post(
        "/transfer",
        json={"recipient": "0x0000000000000000000000000000000000000001", "amount": 1},
    )

    assert response.status_code == 503
    data = response.get_json()
    assert data["status"] == "error"
    assert data["execution_enabled"] is False
    assert "preview mode" in data["message"]
