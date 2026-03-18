import json
import os
import subprocess
import sys
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "tools" / "etherscan" / "eth_balance_tracker.py"
TOOLS_DIR = ROOT / "tools" / "etherscan"


class _FakeResponse:
    def __init__(self, payload: str):
        self.payload = payload.encode("utf-8")

    def read(self):
        return self.payload

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


def load_tracker_module():
    sys.path.insert(0, str(TOOLS_DIR))
    import eth_balance_tracker as tracker

    return tracker


def test_wei_to_eth():
    tracker = load_tracker_module()

    assert tracker.wei_to_eth("1000000000000000000") == "1"
    assert tracker.wei_to_eth("123000000000000000") == "0.123"
    assert tracker.wei_to_eth("0") == "0"


def test_build_url_contains_expected_query():
    tracker = load_tracker_module()

    url = tracker.build_url(
        address="0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
        chainid="1",
        apikey="demo-key",
    )

    assert "module=account" in url
    assert "action=balance" in url
    assert "chainid=1" in url
    assert "apikey=demo-key" in url
    assert "0x71c7656ec7ab88b098defb751b7401b5f6d8976f" in url


def test_get_balance_success():
    tracker = load_tracker_module()

    payload = json.dumps(
        {
            "status": "1",
            "message": "OK",
            "result": "172774397764084972158218",
        }
    )

    with patch("eth_balance_tracker.urllib.request.urlopen", return_value=_FakeResponse(payload)):
        result = tracker.get_balance(
            address="0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
            chainid="1",
            apikey="demo-key",
        )

    assert result["ok"] is True
    assert result["chainid"] == "1"
    assert result["address"] == "0x71c7656ec7ab88b098defb751b7401b5f6d8976f"
    assert result["balance_wei"] == "172774397764084972158218"
    assert result["balance_eth"] == "172774.397764084972158218"


def test_get_balance_retries_rate_limit():
    tracker = load_tracker_module()

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
            "result": "1000000000000000000",
        }
    )

    with patch("eth_balance_tracker.time.sleep") as mocked_sleep, patch(
        "eth_balance_tracker.urllib.request.urlopen",
        side_effect=[_FakeResponse(rate_limited), _FakeResponse(success)],
    ) as mocked_urlopen:
        result = tracker.get_balance(
            address="0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
            chainid="1",
            apikey="demo-key",
        )

    assert result["ok"] is True
    assert result["balance_eth"] == "1"
    assert mocked_urlopen.call_count == 2
    mocked_sleep.assert_called_once_with(1)


def test_cli_success():
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

urllib.request.urlopen = lambda *a, **k: R(json.dumps({{"status": "1", "message": "OK", "result": "1000000000000000000"}}))
sys.argv = ["{SCRIPT.name}", "0x71c7656ec7ab88b098defb751b7401b5f6d8976f", "1"]
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
    assert data["balance_eth"] == "1"


def test_cli_missing_api_key():
    env = os.environ.copy()
    env.pop("ETHERSCAN_API_KEY", None)

    result = subprocess.run(
        [sys.executable, str(SCRIPT), "0x71c7656ec7ab88b098defb751b7401b5f6d8976f", "1"],
        capture_output=True,
        text=True,
        env=env,
        cwd=str(ROOT),
    )

    assert result.returncode != 0
    data = json.loads(result.stdout)
    assert data["ok"] is False
    assert data["error"] == "ETHERSCAN_API_KEY missing"
