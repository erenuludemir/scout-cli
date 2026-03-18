import importlib
import os
import sys

import pytest  # noqa: F401
from flask import Flask


# Ensure project root on path so 'app' and 'integrations' resolve
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:  # pragma: no cover (defensive)
    sys.path.insert(0, ROOT)


def test_root_health():
    import app as root_app

    app = root_app.create_app()
    client = app.test_client()
    r = client.get("/")
    assert r.status_code == 200
    data = r.get_json()
    assert data.get("ok") is True


def test_health_aliases():
    import app as root_app

    app = root_app.create_app()
    client = app.test_client()

    for path in ("/health", "/healthz"):
        response = client.get(path)
        assert response.status_code == 200
        data = response.get_json()
        assert data["ok"] is True
        assert data["status"] == "ok"
        assert "network" in data
        assert "sender" in data
        assert "usdt" in data


def test_v2_tokenholders_route_accepts_documented_aliases(monkeypatch):
    import app as root_app
    from integrations.etherscan.etherscan_v2 import EtherscanV2Client

    calls = {}

    def fake_tokenholder_list(self, contractaddress, page=1, offset=100):
        calls["contractaddress"] = contractaddress
        calls["page"] = page
        calls["offset"] = offset
        return {"status": "1", "message": "OK", "result": []}

    monkeypatch.setenv("ETHERSCAN_API_KEY", "TEST")
    monkeypatch.setattr(EtherscanV2Client, "tokenholder_list", fake_tokenholder_list)

    app = root_app.create_app()
    client = app.test_client()
    response = client.get("/v2/etherscan/tokenholders?contract=0xabc&limit=2")

    assert response.status_code == 200
    assert response.get_json()["status"] == "1"
    assert calls == {"contractaddress": "0xabc", "page": 1, "offset": 2}


def test_tokenholders_route_validates_required_contract(monkeypatch):
    import app as root_app

    monkeypatch.setenv("ETHERSCAN_API_KEY", "TEST")

    app = root_app.create_app()
    client = app.test_client()
    response = client.get("/etherscan/tokenholders")

    assert response.status_code == 400
    data = response.get_json()
    assert data["ok"] is False
    assert "contractaddress" in data["error"]


def test_balance_routes_support_v1_and_v2(monkeypatch):
    import app as root_app
    from integrations.etherscan.etherscan_client import EtherscanClient
    from integrations.etherscan.etherscan_v2 import EtherscanV2Client

    monkeypatch.setenv("ETHERSCAN_API_KEY", "TEST")
    monkeypatch.setattr(EtherscanClient, "get_balance_wei", lambda self, address: 42)
    monkeypatch.setattr(EtherscanV2Client, "get_eth_balance", lambda self, address: 84)

    app = root_app.create_app()
    client = app.test_client()

    v1 = client.get("/etherscan/balance?address=0xabc")
    v2 = client.get("/v2/etherscan/balance?address=0xabc")

    assert v1.status_code == 200
    assert v1.get_json()["v"] == "v1"
    assert v1.get_json()["balance_wei"] == 42

    assert v2.status_code == 200
    assert v2.get_json()["v"] == "v2"
    assert v2.get_json()["balance_wei"] == 84


def test_tokeninfo_and_verify_status_routes(monkeypatch):
    import app as root_app
    from integrations.etherscan.etherscan_client import EtherscanClient

    monkeypatch.setenv("ETHERSCAN_API_KEY", "TEST")
    monkeypatch.setattr(
        EtherscanClient,
        "token_info",
        lambda self, contractaddress: {"status": "1", "result": [{"symbol": "USDT"}]},
    )
    monkeypatch.setattr(
        EtherscanClient,
        "check_verify_status",
        lambda self, guid, **kwargs: {"status": "1", "result": f"verified:{guid}"},
    )

    app = root_app.create_app()
    client = app.test_client()

    tokeninfo = client.get("/etherscan/tokeninfo?contract=0xabc")
    status = client.get("/etherscan/verify/status?guid=guid-123")

    assert tokeninfo.status_code == 200
    assert tokeninfo.get_json()["v"] == "v1"
    assert tokeninfo.get_json()["result"]["status"] == "1"

    assert status.status_code == 200
    assert status.get_json()["result"]["result"] == "verified:guid-123"


def test_register_qai_etherscan_is_idempotent():
    from integrations.etherscan.flask_ext import register_qai_etherscan

    app = Flask(__name__)
    register_qai_etherscan(app)
    register_qai_etherscan(app)

    assert "qai_etherscan" in app.blueprints
    assert "v2.qai_etherscan" in app.blueprints


@pytest.mark.parametrize(
    "mod",
    [
        "integrations",
        "integrations.etherscan",
        "integrations.etherscan.etherscan_v2",
        "integrations.etherscan.flask_ext",
    ],
)
def test_imports(mod):
    importlib.import_module(mod)


def test_package_level_exports():
    import integrations
    import integrations.etherscan as etherscan_pkg

    assert hasattr(integrations, "EtherscanClient")
    assert hasattr(integrations, "EtherscanV2Client")
    assert hasattr(integrations, "register_qai_etherscan")
    assert hasattr(etherscan_pkg, "EtherscanClient")
    assert hasattr(etherscan_pkg, "EtherscanV2Client")
    assert hasattr(etherscan_pkg, "bp")
