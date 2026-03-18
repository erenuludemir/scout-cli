from __future__ import annotations

from pathlib import Path

import numpy as np
import pandas as pd

from quantum_ai_trading.config import QuantumAITradingConfig
from quantum_ai_trading.data_collectors import (
    MacroCollector,
    MarketDataCollector,
    NewsSentimentCollector,
    OnChainCollector,
)
from quantum_ai_trading.datasets import FEATURE_COLUMNS, build_training_dataset
from quantum_ai_trading.grid_leverage_engine import GridLeverageEngine
from quantum_ai_trading.signal_engine import SignalEngine
from quantum_ai_trading.trainer import train_all


def synthetic_market(limit: int = 240) -> pd.DataFrame:
    collector = MarketDataCollector(QuantumAITradingConfig(root_dir=Path.cwd()))
    return collector.build_synthetic_klines(symbol="BTCUSDT", interval="1h", limit=limit)


def test_training_dataset_has_expected_features(monkeypatch, tmp_path):
    cfg = QuantumAITradingConfig(root_dir=tmp_path)
    market = synthetic_market()
    onchain_builder = OnChainCollector(cfg)
    sentiment_builder = NewsSentimentCollector(cfg)
    macro_builder = MacroCollector(cfg)

    monkeypatch.setattr(MarketDataCollector, "load_or_fetch_market", lambda self: market)
    monkeypatch.setattr(
        OnChainCollector,
        "load_or_build",
        lambda self, market_df, cache_name="onchain_proxy.parquet": onchain_builder.build_proxy_metrics(market_df),
    )
    monkeypatch.setattr(
        NewsSentimentCollector,
        "load_or_build",
        lambda self, market_df, cache_name="sentiment_proxy.parquet": sentiment_builder.synthesize_sentiment_series(market_df),
    )
    monkeypatch.setattr(
        MacroCollector,
        "load_or_build",
        lambda self, market_df, cache_name="macro_proxy.parquet": macro_builder.synthesize_macro_series(market_df),
    )

    df = build_training_dataset(cfg)
    assert not df.empty
    assert set(FEATURE_COLUMNS).issubset(df.columns)
    assert "future_return" in df.columns


def test_train_signal_and_grid(monkeypatch, tmp_path):
    cfg = QuantumAITradingConfig(root_dir=tmp_path)
    market = synthetic_market()
    onchain_builder = OnChainCollector(cfg)
    sentiment_builder = NewsSentimentCollector(cfg)
    macro_builder = MacroCollector(cfg)

    monkeypatch.setattr(MarketDataCollector, "load_or_fetch_market", lambda self: market)
    monkeypatch.setattr(
        OnChainCollector,
        "load_or_build",
        lambda self, market_df, cache_name="onchain_proxy.parquet": onchain_builder.build_proxy_metrics(market_df),
    )
    monkeypatch.setattr(
        NewsSentimentCollector,
        "load_or_build",
        lambda self, market_df, cache_name="sentiment_proxy.parquet": sentiment_builder.synthesize_sentiment_series(market_df),
    )
    monkeypatch.setattr(
        MacroCollector,
        "load_or_build",
        lambda self, market_df, cache_name="macro_proxy.parquet": macro_builder.synthesize_macro_series(market_df),
    )

    result = train_all(cfg)
    assert result["supervised"]["dataset_rows"] > 0
    assert Path(result["rl"]["policy_path"]).exists()

    signal = SignalEngine(cfg).generate()
    assert signal.action in {"BUY", "SELL", "HOLD"}
    assert signal.mode == "paper"

    plan = GridLeverageEngine(cfg).recommend(capital=1500)
    assert plan.grid_count >= cfg.grid_min_count
    assert plan.leverage <= cfg.max_leverage
    assert plan.per_grid_capital > 0
