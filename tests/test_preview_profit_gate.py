import json
import os
import subprocess
import sys
from decimal import Decimal
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
TOOLS_DIR = ROOT / "tools" / "profitability"
SCRIPT = TOOLS_DIR / "preview_profit_gate.py"

sys.path.insert(0, str(TOOLS_DIR))
import preview_profit_gate as gate  # noqa: E402


def test_parse_amounts():
    assert gate.parse_amounts("100,250,500") == [
        Decimal("100"),
        Decimal("250"),
        Decimal("500"),
    ]


def test_evaluate_candidate_profitable():
    quote = {
        "from_token": "USDT",
        "to_token": "ETH",
        "quote_out": 0.33,
        "quote_out_raw": "330000000000000000",
        "route": "direct",
        "path": ["USDT", "WETH"],
        "fee_bps": 30,
        "price_impact_bps": 10,
        "slippage_bps": 20,
        "estimated_network_fee_usd": 1.5,
    }
    result = gate.evaluate_candidate(
        quote,
        amount_in=Decimal("1000"),
        target_edge_bps=Decimal("120"),
        min_profit_usd=Decimal("2"),
    )

    assert result["profitable"] is True
    assert result["action"] == "candidate"
    assert result["break_even_edge_bps"] > 0
    assert result["expected_profit_usd"] > 2


def test_best_candidate_prefers_profitable():
    candidates = [
        {"profitable": False, "expected_profit_usd": -1},
        {"profitable": True, "expected_profit_usd": 3},
        {"profitable": True, "expected_profit_usd": 2},
    ]
    assert gate.best_candidate(candidates) == candidates[1]


def test_cli_success():
    quote_payloads = [
        {
            "ok": True,
            "from_token": "USDT",
            "to_token": "ETH",
            "quote_out": 0.033,
            "quote_out_raw": "33000000000000000",
            "route": "direct",
            "path": ["USDT", "WETH"],
            "fee_bps": 30,
            "price_impact_bps": 8,
            "slippage_bps": 20,
            "estimated_network_fee_usd": 0.9,
        },
        {
            "ok": True,
            "from_token": "USDT",
            "to_token": "ETH",
            "quote_out": 0.066,
            "quote_out_raw": "66000000000000000",
            "route": "direct",
            "path": ["USDT", "WETH"],
            "fee_bps": 30,
            "price_impact_bps": 12,
            "slippage_bps": 20,
            "estimated_network_fee_usd": 0.9,
        },
    ]

    bootstrap = "\n".join(
        [
            "import json",
            "import runpy",
            "import sys",
            "from unittest.mock import patch",
            f"sys.path.insert(0, r\"{TOOLS_DIR}\")",
            f"payloads = {repr(quote_payloads)}",
            "def fake_fetch(*args, **kwargs):",
            "    return payloads.pop(0)",
            "with patch(\"preview_profit_gate.fetch_quote\", side_effect=fake_fetch):",
            f"    sys.argv = ['{SCRIPT.name}', 'USDT', 'ETH', '100,200', '120', '1', '20', 'http://127.0.0.1:5003']",
            f"    runpy.run_path(r\"{SCRIPT}\", run_name='__main__')",
        ]
    )
    result = subprocess.run(
        [sys.executable, "-c", bootstrap],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
        check=True,
    )
    data = json.loads(result.stdout)
    assert data["ok"] is True
    assert data["pair"] == "USDT/ETH"
    assert len(data["candidates"]) == 2


def test_cli_invalid_amounts():
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "USDT", "ETH", ""],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )
    assert result.returncode != 0
    data = json.loads(result.stdout)
    assert data["ok"] is False
    assert data["error"] == "invalid_amounts"
