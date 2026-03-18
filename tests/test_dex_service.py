import importlib.util
import os
import sys


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:  # pragma: no cover
    sys.path.insert(0, ROOT)


def load_dex_module():
    module_path = os.path.join(ROOT, "dex", "main.py")
    spec = importlib.util.spec_from_file_location("qai_dex_main", module_path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_health_supports_prefixed_and_unprefixed_routes():
    dex_main = load_dex_module()
    client = dex_main.create_app().test_client()

    for path in ("/health", "/dex/health"):
        response = client.get(path)
        assert response.status_code == 200
        data = response.get_json()
        assert data["ok"] is True
        assert data["service"] == "dex"
        assert "/quote" in data["endpoints"]


def test_quote_accepts_documented_raw_amount_request():
    dex_main = load_dex_module()
    client = dex_main.create_app().test_client()

    response = client.post("/quote", json={"from": "USDT", "to": "WETH", "amount": 1000000})

    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ok"
    assert data["mode"] == "preview"
    assert data["from_token"] == "USDT"
    assert data["to_token"] == "WETH"
    assert data["amount_in_raw"] == "1000000"
    assert data["amount_in"] == 1.0
    assert data["route"] == "direct"
    assert data["path"] == ["USDT", "WETH"]
    assert data["quote_out"] > data["min_out"] > 0
    assert data["gas_estimate"] > 0


def test_quote_routes_non_bridge_pairs_via_weth():
    dex_main = load_dex_module()
    client = dex_main.create_app().test_client()

    response = client.post("/dex/quote", json={"from": "USDT", "to": "WBTC", "amount": 1000000})

    assert response.status_code == 200
    data = response.get_json()
    assert data["route"] == "via-weth"
    assert data["path"] == ["USDT", "WETH", "WBTC"]
    assert data["fee_bps"] == 60


def test_swap_keeps_legacy_request_shape_and_returns_preview():
    dex_main = load_dex_module()
    client = dex_main.create_app().test_client()

    response = client.post(
        "/swap",
        json={
            "from_token": "ETH",
            "to_token": "USDT",
            "amount_in": 1.5,
            "slippage_bps": 75,
        },
    )

    assert response.status_code == 200
    data = response.get_json()
    assert data["status"] == "ok"
    assert data["submit_status"] == "preview_only"
    assert data["from_token"] == "ETH"
    assert data["to_token"] == "USDT"
    assert data["route"] == "direct"
    assert data["path"] == ["WETH", "USDT"]
    assert data["quote_out"] > data["min_out"] > 0


def test_quote_rejects_unsupported_assets():
    dex_main = load_dex_module()
    client = dex_main.create_app().test_client()

    response = client.post("/quote", json={"from": "SOL", "to": "USDT", "amount": 1})

    assert response.status_code == 400
    data = response.get_json()
    assert data["ok"] is False
    assert "unsupported from_token" in data["error"]
