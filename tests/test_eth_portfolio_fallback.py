import json
import os
import subprocess
import sys
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
TOOLS_DIR = ROOT / "tools" / "etherscan"
SCRIPT = TOOLS_DIR / "eth_portfolio_fallback.py"

sys.path.insert(0, str(TOOLS_DIR))
import eth_portfolio_fallback as tracker  # noqa: E402


def test_parse_contracts_defaults():
    contracts = tracker.parse_contracts("")
    assert "0xdac17f958d2ee523a2206206994597c13d831ec7" in contracts
    assert "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48" in contracts


def test_token_to_decimal():
    assert tracker.token_to_decimal("1500000", "6") == "1.5"
    assert tracker.token_to_decimal("100", "6") == "0.0001"
    assert tracker.token_to_decimal("0", "18") == "0"


def test_summarize_tokentx_for_address():
    address = "0x71c7656ec7ab88b098defb751b7401b5f6d8976f"
    items = [
        {
            "hash": "0x1",
            "from": "0x0000000000000000000000000000000000000001",
            "to": address,
            "value": "1500000",
            "tokenDecimal": "6",
            "tokenSymbol": "USDC",
            "tokenName": "USD Coin",
            "contractAddress": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        },
        {
            "hash": "0x2",
            "from": address,
            "to": "0x0000000000000000000000000000000000000002",
            "value": "500000",
            "tokenDecimal": "6",
            "tokenSymbol": "USDC",
            "tokenName": "USD Coin",
            "contractAddress": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        },
    ]
    result = tracker.summarize_tokentx_for_address(address, items)
    assert result["net_raw"] == "1000000"
    assert result["net_balance_decimal"] == "1"
    assert result["incoming_count"] == 1
    assert result["outgoing_count"] == 1


def test_build_fallback_portfolio():
    with patch("eth_portfolio_fallback.get_balance") as mock_balance, patch("eth_portfolio_fallback.get_tokentx") as mock_tokentx:
        mock_balance.return_value = {
            "ok": True,
            "source": "etherscan_v2",
            "chainid": "1",
            "address": "0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
            "balance_wei": "1000000000000000000",
            "balance_eth": "1",
        }
        mock_tokentx.side_effect = [
            {
                "ok": True,
                "count": 2,
                "items": [
                    {
                        "hash": "0x1",
                        "from": "0x0000000000000000000000000000000000000001",
                        "to": "0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
                        "value": "1500000",
                        "tokenDecimal": "6",
                        "tokenSymbol": "USDC",
                        "tokenName": "USD Coin",
                        "contractAddress": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                    },
                    {
                        "hash": "0x2",
                        "from": "0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
                        "to": "0x0000000000000000000000000000000000000002",
                        "value": "500000",
                        "tokenDecimal": "6",
                        "tokenSymbol": "USDC",
                        "tokenName": "USD Coin",
                        "contractAddress": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                    },
                ],
            },
            {
                "ok": True,
                "count": 1,
                "items": [
                    {
                        "hash": "0x3",
                        "from": "0x0000000000000000000000000000000000000003",
                        "to": "0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
                        "value": "100",
                        "tokenDecimal": "6",
                        "tokenSymbol": "USDT",
                        "tokenName": "Tether USD",
                        "contractAddress": "0xdac17f958d2ee523a2206206994597c13d831ec7",
                    }
                ],
            },
        ]

        result = tracker.build_fallback_portfolio(
            address="0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
            chainid="1",
            apikey="demo",
            contracts=[
                "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
                "0xdac17f958d2ee523a2206206994597c13d831ec7",
            ],
        )

    assert result["ok"] is True
    assert result["mode"] == "portfolio_fallback"
    assert result["native"]["balance_eth"] == "1"
    assert result["token_count"] == 2
    assert result["tokens"][0]["tokenSymbol"] == "USDC"
    assert result["tokens"][0]["net_balance_decimal"] == "1"
    assert result["tokens"][1]["tokenSymbol"] == "USDT"
    assert result["tokens"][1]["net_balance_decimal"] == "0.0001"


def test_cli_missing_api_key():
    env = os.environ.copy()
    env.pop("ETHERSCAN_API_KEY", None)
    env.pop("API_KEY_ETHERSCAN", None)

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


def test_cli_success():
    env = os.environ.copy()
    env["ETHERSCAN_API_KEY"] = "demo-key"

    bootstrap = f"""
import sys
from unittest.mock import patch

sys.path.insert(0, r"{TOOLS_DIR}")
import eth_portfolio_fallback as mod

balance_payload = {{
    "ok": True,
    "source": "etherscan_v2",
    "chainid": "1",
    "address": "0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
    "balance_wei": "1000000000000000000",
    "balance_eth": "1"
}}

tokentx_side_effect = [
    {{
        "ok": True,
        "count": 1,
        "items": [{{
            "hash": "0x1",
            "from": "0x0000000000000000000000000000000000000001",
            "to": "0x71c7656ec7ab88b098defb751b7401b5f6d8976f",
            "value": "1000000",
            "tokenDecimal": "6",
            "tokenSymbol": "USDC",
            "tokenName": "USD Coin",
            "contractAddress": "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
        }}]
    }}
]

with patch.object(mod, "get_balance", return_value=balance_payload), patch.object(mod, "get_tokentx", side_effect=tokentx_side_effect):
    sys.argv = ["{SCRIPT.name}", "0x71c7656ec7ab88b098defb751b7401b5f6d8976f", "1", "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"]
    mod.main()
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
    assert data["mode"] == "portfolio_fallback"
    assert data["native"]["balance_eth"] == "1"
    assert data["tokens"][0]["tokenSymbol"] == "USDC"
