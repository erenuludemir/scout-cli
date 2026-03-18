from __future__ import annotations

import json
from pathlib import Path

import pandas as pd
from fastapi.testclient import TestClient

from ai.api.ai_bot_api import app as ai_api_app
from ai.data.market_data_pipeline import build_technical_features
from ai.signals.signal_engine import generate_latest_signal
from ai.strategies.grid_leverage_engine import build_strategy_plan
from ai.training.reinforcement_trainer import train_from_root as train_rl_from_root
from ai.training.supervised_trainer import train_from_root as train_supervised_from_root
from token_factory.api.token_factory_api import app as token_api_app


def make_dataset(root: Path) -> None:
    n = 140
    idx = pd.date_range("2025-01-01", periods=n, freq="h", tz="UTC")
    base = pd.DataFrame(
        {
            "open_time": idx,
            "open": pd.Series(range(n), dtype=float) + 50000.0,
            "high": pd.Series(range(n), dtype=float) + 50100.0,
            "low": pd.Series(range(n), dtype=float) + 49900.0,
            "close": pd.Series(range(n), dtype=float) + 50020.0,
            "volume": pd.Series(range(n), dtype=float) + 1000.0,
            "close_time": idx,
            "quote_asset_volume": pd.Series(range(n), dtype=float) + 2_000_000.0,
            "number_of_trades": pd.Series(range(n), dtype=float) + 1500.0,
            "taker_buy_base": pd.Series(range(n), dtype=float) + 500.0,
            "taker_buy_quote": pd.Series(range(n), dtype=float) + 1_000_000.0,
            "ignore": 0,
            "symbol": "BTCUSDT",
            "interval": "1h",
        }
    )
    tech = build_technical_features(base)
    tech["sentiment_score"] = 0.1
    tech["fear_greed_index"] = 55.0
    tech["news_impact_flag"] = 0
    tech["active_addresses_proxy"] = 120000.0
    tech["tx_value_proxy"] = 500000.0
    tech["miner_flow_proxy"] = -100.0
    tech["exchange_netflow_proxy"] = -50.0
    tech["staking_ratio_proxy"] = 0.22
    tech["macro_dxy"] = 103.0
    tech["macro_fed_rate"] = 4.75
    tech["macro_cpi_yoy"] = 2.8
    tech["macro_us10y"] = 4.1
    tech["macro_liquidity_idx"] = 51.0
    tech["best_bid"] = tech["close"] - 5.0
    tech["best_ask"] = tech["close"] + 5.0
    tech["spread"] = 10.0
    tech["spread_bps"] = 2.0
    tech["top10_bid_qty"] = 1000.0
    tech["top10_ask_qty"] = 950.0
    tech["book_imbalance"] = 0.08
    tech["dataset_generated_at"] = "2025-01-01T00:00:00+00:00"

    ds_dir = root / "ai" / "data" / "datasets"
    ds_dir.mkdir(parents=True, exist_ok=True)
    tech.to_csv(ds_dir / "sample.csv", index=False)


def test_ai_training_signal_and_grid_roundtrip(tmp_path, monkeypatch):
    monkeypatch.setenv("QAI_ROOT", str(tmp_path))
    make_dataset(tmp_path)

    supervised = train_supervised_from_root(tmp_path)
    rl = train_rl_from_root(tmp_path)
    signal = generate_latest_signal(tmp_path)
    grid = build_strategy_plan(tmp_path, account_equity=10000.0, risk_pct=0.01)

    assert supervised["ok"] is True
    assert rl["ok"] is True
    assert signal["ok"] is True
    assert signal["signal"] in {"SELL", "HOLD", "BUY"}
    assert grid["ok"] is True
    assert grid["mode"] in {"GRID", "TREND_LEVERAGE"}


def test_ai_api_health():
    client = TestClient(ai_api_app)
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["ok"] is True


def test_token_factory_api_health_and_compile(tmp_path, monkeypatch):
    monkeypatch.setenv("QAI_ROOT", str(tmp_path))
    tf_root = tmp_path / "token_factory"
    (tf_root / "contracts").mkdir(parents=True, exist_ok=True)
    (tf_root / "contracts" / "QuantumERC20Token.sol").write_text(
        "pragma solidity ^0.8.24; contract QuantumERC20Token {}",
        encoding="utf-8",
    )
    (tf_root / "contracts" / "QuantumTRC20Token.sol").write_text(
        "pragma solidity ^0.8.24; contract QuantumTRC20Token {}",
        encoding="utf-8",
    )

    client = TestClient(token_api_app)
    health = client.get("/health")
    assert health.status_code == 200
    assert health.json()["ok"] is True
