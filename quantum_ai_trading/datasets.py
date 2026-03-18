from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pandas as pd

from .config import QuantumAITradingConfig
from .data_collectors import (
    MacroCollector,
    MarketDataCollector,
    NewsSentimentCollector,
    OnChainCollector,
)
from .feature_pipeline import add_technical_features


FEATURE_COLUMNS = [
    "ret_1",
    "ret_4",
    "ret_12",
    "ret_24",
    "vol_chg_1",
    "volatility_12",
    "volatility_24",
    "rsi_14",
    "ema_cross",
    "macd_line",
    "macd_signal",
    "macd_hist",
    "bb_width",
    "atr_14",
    "distance_to_fib_382",
    "distance_to_fib_618",
    "price_position_55",
    "active_addresses_proxy",
    "transfer_value_proxy",
    "miner_sell_pressure_proxy",
    "staking_ratio_proxy",
    "sentiment_index",
    "headline_score",
    "macro_risk_index",
    "dxy_proxy",
]


def build_training_dataset(config: QuantumAITradingConfig) -> pd.DataFrame:
    market = MarketDataCollector(config).load_or_fetch_market()
    market = add_technical_features(market)

    onchain = OnChainCollector(config).load_or_build(market)
    sentiment = NewsSentimentCollector(config).load_or_build(market)
    macro = MacroCollector(config).load_or_build(market)

    df = market.merge(onchain, on="open_time", how="left")
    df = df.merge(sentiment, on="open_time", how="left")
    df = df.merge(macro, on="open_time", how="left")

    horizon = config.label_horizon
    future_return = df["close"].shift(-horizon) / df["close"] - 1.0
    df["future_return"] = future_return.fillna(0.0)
    df["label_up"] = (df["future_return"] >= config.classification_threshold_up).astype(int)
    df["label_down"] = (df["future_return"] <= config.classification_threshold_down).astype(int)
    df["label_sideways"] = ((df["label_up"] == 0) & (df["label_down"] == 0)).astype(int)
    df["label_action"] = np.select(
        [df["label_up"] == 1, df["label_down"] == 1],
        [1, -1],
        default=0,
    )
    if horizon > 0:
        df = df.iloc[:-horizon]
    df.replace([np.inf, -np.inf], np.nan, inplace=True)
    df.bfill(inplace=True)
    df.ffill(inplace=True)
    df.fillna(0.0, inplace=True)
    return df


def latest_feature_row(df: pd.DataFrame) -> dict[str, float]:
    row = df.iloc[-1]
    return {col: float(row[col]) for col in FEATURE_COLUMNS}


def persist_dataset(df: pd.DataFrame, path: str | Path) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    df.to_parquet(target, index=False)


def persist_manifest(config: QuantumAITradingConfig, df: pd.DataFrame, path: str | Path) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "symbol": config.symbol,
        "interval": config.interval,
        "rows": int(len(df)),
        "features": FEATURE_COLUMNS,
        "label_horizon": config.label_horizon,
    }
    target.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
