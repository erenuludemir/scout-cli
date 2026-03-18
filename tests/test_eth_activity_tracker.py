import json
import os
import subprocess
import sys
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
TOOLS_DIR = ROOT / "tools" / "etherscan"
SCRIPT = TOOLS_DIR / "eth_activity_tracker.py"

sys.path.insert(0, str(TOOLS_DIR))
import eth_activity_tracker as tracker  # noqa: E402


class _FakeResponse:
    def __init__(self, payload: str):
        self.payload = payload.encode("utf-8")

    def read(self):
        return self.payload

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


def test_build_url_txlist_contains_expected_query():
    url = tracker.build_url(
        "txlist",
        apikey="demo",
        address="0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
        chainid="1",
        page="1",
        offset="10",
        sort="desc",
    )
    assert "action=txlist" in url
    assert "address=0x71c7656ec7ab88b098defb751b7401b5f6d8976f" in url
    assert "chainid=1" in url
    assert "page=1" in url
    assert "offset=10" in url
    assert "sort=desc" in url


def test_get_txlist_success():
    payload = json.dumps(
        {
            "status": "1",
            "message": "OK",
            "result": [
                {
                    "hash": "0xabc",
                    "value": "1000000000000000000",
                    "from": "0x1111111111111111111111111111111111111111",
                    "to": "0x2222222222222222222222222222222222222222",
                }
            ],
        }
    )
    with patch("eth_activity_tracker.urllib.request.urlopen", return_value=_FakeResponse(payload)):
        result = tracker.get_txlist(
            address="0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
            chainid="1",
            apikey="demo",
            page="1",
            offset="10",
            sort="desc",
        )
    assert result["ok"] is True
    assert result["mode"] == "txlist"
    assert result["count"] == 1
    assert result["items"][0]["value_eth"] == "1"


def test_get_tokentx_success():
    payload = json.dumps(
        {
            "status": "1",
            "message": "OK",
            "result": [
                {
                    "hash": "0xdef",
                    "value": "1234500",
                    "tokenDecimal": "4",
                    "tokenSymbol": "USDT",
                }
            ],
        }
    )
    with patch("eth_activity_tracker.urllib.request.urlopen", return_value=_FakeResponse(payload)):
        result = tracker.get_tokentx(
            address="0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
            chainid="1",
            apikey="demo",
            contractaddress="0xdac17f958d2ee523a2206206994597c13d831ec7",
            page="1",
            offset="10",
            sort="desc",
        )
    assert result["ok"] is True
    assert result["mode"] == "tokentx"
    assert result["items"][0]["value_decimal"] == "123.45"


def test_get_portfolio_success():
    payload = json.dumps(
        {
            "status": "1",
            "message": "OK",
            "result": [
                {
                    "TokenAddress": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                    "TokenQuantity": "1500000",
                    "TokenDivisor": "6",
                    "TokenSymbol": "USDC",
                }
            ],
        }
    )
    with patch("eth_activity_tracker.urllib.request.urlopen", return_value=_FakeResponse(payload)):
        result = tracker.get_portfolio(
            address="0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
            chainid="1",
            apikey="demo",
        )
    assert result["ok"] is True
    assert result["mode"] == "portfolio"
    assert result["items"][0]["balance_decimal"] == "1.5"


def test_get_portfolio_surfaces_pro_endpoint_error():
    payload = json.dumps(
        {
            "status": "0",
            "message": "NOTOK",
            "result": "Sorry, it looks like you are trying to access an API Pro endpoint. Contact us to upgrade to API Pro.",
        }
    )
    with patch("eth_activity_tracker.urllib.request.urlopen", return_value=_FakeResponse(payload)):
        try:
            tracker.get_portfolio(
                address="0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
                chainid="1",
                apikey="demo",
            )
        except SystemExit as exc:
            assert exc.code == 1
        else:  # pragma: no cover
            raise AssertionError("expected SystemExit")


def test_get_portfolio_retries_rate_limit():
    rate_limited = json.dumps(
        {
            "status": "0",
            "message": "NOTOK",
            "result": "Max calls per sec rate limit reached (3/sec)",
        }
    )
    success = json.dumps(
        {
            "status": "1",
            "message": "OK",
            "result": [
                {
                    "TokenAddress": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                    "TokenQuantity": "1500000",
                    "TokenDivisor": "6",
                    "TokenSymbol": "USDC",
                }
            ],
        }
    )
    with patch("eth_activity_tracker.time.sleep") as mocked_sleep, patch(
        "eth_activity_tracker.urllib.request.urlopen",
        side_effect=[_FakeResponse(rate_limited), _FakeResponse(success)],
    ) as mocked_urlopen:
        result = tracker.get_portfolio(
            address="0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
            chainid="1",
            apikey="demo",
        )

    assert result["ok"] is True
    assert result["mode"] == "portfolio"
    assert result["items"][0]["balance_decimal"] == "1.5"
    assert mocked_urlopen.call_count == 2
    mocked_sleep.assert_called_once_with(1)


def test_cli_txlist_success():
    env = os.environ.copy()
    env["ETHERSCAN_API_KEY"] = "demo-key"
    bootstrap = f"""
import json
import runpy
import sys
import urllib.request

class R:
    def __init__(self, payload):
        self.payload = payload.encode("utf-8")

    def read(self):
        return self.payload

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

urllib.request.urlopen = lambda *a, **k: R(json.dumps({{"status": "1", "message": "OK", "result": [{{"hash": "0xabc", "value": "1000000000000000000"}}]}}))
sys.argv = ["{SCRIPT.name}", "txlist", "0x71c7656ec7ab88b098defb751b7401b5f6d8976f", "1", "1", "10", "desc"]
runpy.run_path(r"{SCRIPT}", run_name="__main__")
"""
    result = subprocess.run(
        [sys.executable, "-c", bootstrap],
        capture_output=True,
        text=True,
        env=env,
        cwd=str(ROOT),
        check=True,
    )
    data = json.loads(result.stdout)
    assert data["ok"] is True
    assert data["mode"] == "txlist"
    assert data["items"][0]["value_eth"] == "1"


def test_cli_missing_api_key():
    env = os.environ.copy()
    env.pop("ETHERSCAN_API_KEY", None)
    env.pop("API_KEY_ETHERSCAN", None)
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "portfolio", "0x71c7656ec7ab88b098defb751b7401b5f6d8976f", "1"],
        capture_output=True,
        text=True,
        env=env,
        cwd=str(ROOT),
    )
    assert result.returncode != 0
    data = json.loads(result.stdout)
    assert data["ok"] is False
    assert data["error"] == "ETHERSCAN_API_KEY missing"
