import os
import sys

from flask import Flask


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:  # pragma: no cover
    sys.path.insert(0, ROOT)


def test_wallet_networks_route_lists_major_families():
    import app as root_app

    app = root_app.create_app()
    client = app.test_client()
    response = client.get("/wallet/networks")

    assert response.status_code == 200
    payload = response.get_json()
    ids = {item["id"] for item in payload["result"]}
    assert {"ethereum", "base", "tron", "solana", "bitcoin"}.issubset(ids)


def test_wallet_balance_route_delegates_to_service(monkeypatch):
    import app as root_app
    from integrations.wallet.multichain import MultiChainWalletService

    calls = {}

    def fake_get_balance(self, *, network, address):
        calls["network"] = network
        calls["address"] = address
        return {"network": network, "address": address, "balance": "1.5"}

    monkeypatch.setattr(MultiChainWalletService, "get_balance", fake_get_balance)

    app = root_app.create_app()
    client = app.test_client()
    response = client.get("/wallet/balance?network=base&address=0xabc")

    assert response.status_code == 200
    assert response.get_json()["result"]["balance"] == "1.5"
    assert calls == {"network": "base", "address": "0xabc"}


def test_wallet_token_balance_route_accepts_contract_alias(monkeypatch):
    import app as root_app
    from integrations.wallet.multichain import MultiChainWalletService

    calls = {}

    def fake_get_token_balance(self, *, network, address, token_address):
        calls["network"] = network
        calls["address"] = address
        calls["token_address"] = token_address
        return {"balance_raw": "42"}

    monkeypatch.setattr(MultiChainWalletService, "get_token_balance", fake_get_token_balance)

    app = root_app.create_app()
    client = app.test_client()
    response = client.get("/wallet/token-balance?network=ethereum&address=0xabc&contractaddress=0xdef")

    assert response.status_code == 200
    assert response.get_json()["result"]["balance_raw"] == "42"
    assert calls == {"network": "ethereum", "address": "0xabc", "token_address": "0xdef"}


def test_wallet_broadcast_route_accepts_payload(monkeypatch):
    import app as root_app
    from integrations.wallet.multichain import MultiChainWalletService

    calls = {}

    def fake_broadcast(self, *, network, raw_transaction=None, payload=None, encoding=None):
        calls["network"] = network
        calls["raw_transaction"] = raw_transaction
        calls["payload"] = payload
        calls["encoding"] = encoding
        return {"tx_hash": "0xhash"}

    monkeypatch.setattr(MultiChainWalletService, "broadcast", fake_broadcast)

    app = root_app.create_app()
    client = app.test_client()
    response = client.post(
        "/wallet/broadcast",
        json={
            "network": "solana",
            "raw_transaction": "BASE64_TX",
            "encoding": "base64",
            "payload": {"skipPreflight": True},
        },
    )

    assert response.status_code == 200
    assert response.get_json()["result"]["tx_hash"] == "0xhash"
    assert calls == {
        "network": "solana",
        "raw_transaction": "BASE64_TX",
        "payload": {"skipPreflight": True},
        "encoding": "base64",
    }


def test_wallet_portfolio_route_aggregates(monkeypatch):
    import app as root_app
    from integrations.wallet.multichain import MultiChainWalletService

    def fake_build_portfolio(self, *, addresses, networks=None):
        return {
            "ok": True,
            "results": [
                {"network": "ethereum", "family": "evm", "ok": True, "balance": {"balance": "2"}},
                {"network": "tron", "family": "tron", "ok": True, "balance": {"balance": "8"}},
            ],
            "addresses": addresses,
            "networks": list(networks or []),
        }

    monkeypatch.setattr(MultiChainWalletService, "build_portfolio", fake_build_portfolio)

    app = root_app.create_app()
    client = app.test_client()
    response = client.post(
        "/wallet/portfolio",
        json={"addresses": {"evm": "0xabc", "tron": "TQ1"}, "networks": ["ethereum", "tron"]},
    )

    assert response.status_code == 200
    payload = response.get_json()["result"]
    assert payload["ok"] is True
    assert payload["results"][0]["network"] == "ethereum"
    assert payload["results"][1]["network"] == "tron"


def test_multichain_service_resolves_chain_aliases():
    from integrations.wallet.multichain import MultiChainWalletService

    service = MultiChainWalletService()

    assert service.resolve_network("1").id == "ethereum"
    assert service.resolve_network("8453").id == "base"
    assert service.resolve_network("trc20").id == "tron"
    assert service.resolve_network("btc").id == "bitcoin"


def test_register_qai_wallet_is_idempotent():
    from integrations.wallet.flask_ext import register_qai_wallet

    app = Flask(__name__)
    register_qai_wallet(app)
    register_qai_wallet(app)

    assert "qai_wallet" in app.blueprints
