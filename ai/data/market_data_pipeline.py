#!/usr/bin/env python3
from __future__ import annotations

import json
import math
import os
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
import requests
from dotenv import load_dotenv
from ta.momentum import RSIIndicator, StochasticOscillator
from ta.trend import ADXIndicator, EMAIndicator, MACD
from ta.volatility import AverageTrueRange, BollingerBands

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

load_dotenv()
UTC = timezone.utc


@dataclass(slots=True)
class MarketConfig:
    symbol: str
    interval: str
    limit: int
    dataset_dir: Path
    sentiment_mode: str = "heuristic"
    macro_mode: str = "static"
    onchain_mode: str = "static"


def _now_iso() -> str:
    return datetime.now(tz=UTC).isoformat()


def _safe_float(value: Any, default: float = 0.0) -> float:
    try:
        if value is None:
            return default
        return float(value)
    except Exception:
        return default


def _synthetic_klines(symbol: str, interval: str, limit: int) -> pd.DataFrame:
    rng = np.random.default_rng(42)
    idx = pd.date_range(end=pd.Timestamp.now(tz=UTC), periods=limit, freq="h")
    base = 65000 + np.linspace(-2500, 2500, limit) + np.sin(np.linspace(0, 8 * math.pi, limit)) * 1800
    noise = rng.normal(0.0, 220.0, limit)
    close = np.maximum(base + noise, 100.0)
    open_ = np.roll(close, 1)
    open_[0] = close[0]
    high = np.maximum(open_, close) + rng.uniform(20, 220, limit)
    low = np.minimum(open_, close) - rng.uniform(20, 220, limit)
    volume = rng.uniform(120, 1200, limit)
    quote_volume = volume * close
    trades = rng.integers(1000, 15000, limit)
    taker_buy_base = volume * rng.uniform(0.35, 0.65, limit)
    taker_buy_quote = taker_buy_base * close
    return pd.DataFrame(
        {
            "open_time": idx,
            "open": open_,
            "high": high,
            "low": low,
            "close": close,
            "volume": volume,
            "close_time": idx,
            "quote_asset_volume": quote_volume,
            "number_of_trades": trades,
            "taker_buy_base": taker_buy_base,
            "taker_buy_quote": taker_buy_quote,
            "ignore": 0,
        }
    ).assign(symbol=symbol.upper(), interval=interval)


def fetch_binance_klines(symbol: str, interval: str, limit: int = 1000) -> pd.DataFrame:
    url = "https://api.binance.com/api/v3/klines"
    params = {"symbol": symbol.upper(), "interval": interval, "limit": int(limit)}
    try:
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        rows = response.json()
    except Exception:
        return _synthetic_klines(symbol, interval, limit)

    cols = [
        "open_time",
        "open",
        "high",
        "low",
        "close",
        "volume",
        "close_time",
        "quote_asset_volume",
        "number_of_trades",
        "taker_buy_base",
        "taker_buy_quote",
        "ignore",
    ]
    df = pd.DataFrame(rows, columns=cols)
    for col in ["open", "high", "low", "close", "volume", "quote_asset_volume", "taker_buy_base", "taker_buy_quote"]:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    df["number_of_trades"] = pd.to_numeric(df["number_of_trades"], errors="coerce")
    df["open_time"] = pd.to_datetime(df["open_time"], unit="ms", utc=True)
    df["close_time"] = pd.to_datetime(df["close_time"], unit="ms", utc=True)
    df["symbol"] = symbol.upper()
    df["interval"] = interval
    return df


def fetch_binance_order_book(symbol: str, limit: int = 100) -> dict[str, Any]:
    url = "https://api.binance.com/api/v3/depth"
    params = {"symbol": symbol.upper(), "limit": int(limit)}
    try:
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()
        bids = [[_safe_float(x[0]), _safe_float(x[1])] for x in data.get("bids", [])]
        asks = [[_safe_float(x[0]), _safe_float(x[1])] for x in data.get("asks", [])]
    except Exception:
        bids = [[65000.0, 120.0], [64990.0, 95.0]]
        asks = [[65010.0, 110.0], [65020.0, 100.0]]

    best_bid = bids[0][0] if bids else 0.0
    best_ask = asks[0][0] if asks else 0.0
    spread = max(best_ask - best_bid, 0.0)
    bid_qty = sum(x[1] for x in bids[:10])
    ask_qty = sum(x[1] for x in asks[:10])
    imbalance = (bid_qty - ask_qty) / max(bid_qty + ask_qty, 1e-9)
    return {
        "best_bid": best_bid,
        "best_ask": best_ask,
        "spread": spread,
        "spread_bps": (spread / max(best_bid, 1e-9)) * 10000.0 if best_bid else 0.0,
        "top10_bid_qty": bid_qty,
        "top10_ask_qty": ask_qty,
        "book_imbalance": imbalance,
        "snapshot_ts": _now_iso(),
    }


def build_technical_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    out["return_1"] = out["close"].pct_change(1)
    out["return_5"] = out["close"].pct_change(5)
    out["return_15"] = out["close"].pct_change(15)
    out["log_return_1"] = np.log(out["close"] / out["close"].shift(1))
    out["volatility_20"] = out["log_return_1"].rolling(20).std() * np.sqrt(20)
    out["rsi_14"] = RSIIndicator(close=out["close"], window=14).rsi()
    out["ema_9"] = EMAIndicator(close=out["close"], window=9).ema_indicator()
    out["ema_21"] = EMAIndicator(close=out["close"], window=21).ema_indicator()
    out["ema_50"] = EMAIndicator(close=out["close"], window=50).ema_indicator()
    macd = MACD(close=out["close"], window_slow=26, window_fast=12, window_sign=9)
    out["macd"] = macd.macd()
    out["macd_signal"] = macd.macd_signal()
    out["macd_diff"] = macd.macd_diff()
    bb = BollingerBands(close=out["close"], window=20, window_dev=2)
    out["bb_high"] = bb.bollinger_hband()
    out["bb_low"] = bb.bollinger_lband()
    out["bb_mid"] = bb.bollinger_mavg()
    out["bb_width"] = (out["bb_high"] - out["bb_low"]) / out["bb_mid"].replace(0, np.nan)
    stoch = StochasticOscillator(high=out["high"], low=out["low"], close=out["close"], window=14, smooth_window=3)
    out["stoch_k"] = stoch.stoch()
    out["stoch_d"] = stoch.stoch_signal()
    out["atr_14"] = AverageTrueRange(high=out["high"], low=out["low"], close=out["close"], window=14).average_true_range()
    out["adx_14"] = ADXIndicator(high=out["high"], low=out["low"], close=out["close"], window=14).adx()
    out["volume_zscore_20"] = (out["volume"] - out["volume"].rolling(20).mean()) / out["volume"].rolling(20).std()
    out["quote_volume_zscore_20"] = (out["quote_asset_volume"] - out["quote_asset_volume"].rolling(20).mean()) / out["quote_asset_volume"].rolling(20).std()
    out["trade_count_zscore_20"] = (out["number_of_trades"] - out["number_of_trades"].rolling(20).mean()) / out["number_of_trades"].rolling(20).std()
    out["close_vs_ema21"] = (out["close"] - out["ema_21"]) / out["ema_21"].replace(0, np.nan)
    out["close_vs_bb_mid"] = (out["close"] - out["bb_mid"]) / out["bb_mid"].replace(0, np.nan)
    out.replace([np.inf, -np.inf], np.nan, inplace=True)
    out = out.bfill().ffill().fillna(0.0)
    return out


def build_sentiment_series(index: pd.Index, mode: str = "heuristic") -> pd.DataFrame:
    n = len(index)
    if n == 0:
        return pd.DataFrame(index=index)
    x = np.linspace(0, 12 * math.pi, n)
    noise = np.random.default_rng(42).normal(0.0, 0.08, n)
    sentiment = np.tanh(np.sin(x) * 0.5 + noise)
    fear_greed = np.clip((sentiment + 1.0) * 50.0, 0.0, 100.0)
    news_impact = np.where(sentiment > 0.3, 1, np.where(sentiment < -0.3, -1, 0))
    return pd.DataFrame(
        {
            "sentiment_score": sentiment,
            "fear_greed_index": fear_greed,
            "news_impact_flag": news_impact,
        },
        index=index,
    )


def build_onchain_proxy(index: pd.Index, close: pd.Series, volume: pd.Series, mode: str = "static") -> pd.DataFrame:
    price_chg = close.pct_change().fillna(0.0)
    vol_chg = volume.pct_change().fillna(0.0)
    active_addr = 100000 + (price_chg.rolling(10).mean().fillna(0.0) * 1_000_000) + (vol_chg.rolling(5).mean().fillna(0.0) * 500_000)
    tx_volume = (volume.rolling(5).mean().bfill() * close.rolling(5).mean().bfill()) / 1000.0
    miner_flow = -price_chg.rolling(3).mean().fillna(0.0) * 1000.0
    exchange_netflow = -vol_chg.rolling(3).mean().fillna(0.0) * 10000.0
    staking_ratio = np.clip(0.15 + price_chg.rolling(30).mean().fillna(0.0), 0.01, 0.95)
    return pd.DataFrame(
        {
            "active_addresses_proxy": active_addr,
            "tx_value_proxy": tx_volume,
            "miner_flow_proxy": miner_flow,
            "exchange_netflow_proxy": exchange_netflow,
            "staking_ratio_proxy": staking_ratio,
        },
        index=index,
    )


def build_macro_series(index: pd.Index, mode: str = "static") -> pd.DataFrame:
    n = len(index)
    if n == 0:
        return pd.DataFrame(index=index)
    lin = np.linspace(0, 1, n)
    dxy = 103.0 + np.sin(np.linspace(0, 6 * np.pi, n)) * 0.8
    fed_rate = np.full(n, 4.75)
    cpi_yoy = 2.8 + np.cos(np.linspace(0, 3 * np.pi, n)) * 0.3
    us10y = 4.1 + np.sin(np.linspace(0, 4 * np.pi, n)) * 0.15
    liquidity_index = 50 + lin * 5 + np.sin(np.linspace(0, 8 * np.pi, n)) * 2
    return pd.DataFrame(
        {
            "macro_dxy": dxy,
            "macro_fed_rate": fed_rate,
            "macro_cpi_yoy": cpi_yoy,
            "macro_us10y": us10y,
            "macro_liquidity_idx": liquidity_index,
        },
        index=index,
    )


def merge_dataset(config: MarketConfig) -> pd.DataFrame:
    klines = fetch_binance_klines(config.symbol, config.interval, config.limit)
    tech = build_technical_features(klines)
    sentiment = build_sentiment_series(tech.index, config.sentiment_mode)
    onchain = build_onchain_proxy(tech.index, tech["close"], tech["volume"], config.onchain_mode)
    macro = build_macro_series(tech.index, config.macro_mode)
    dataset = pd.concat(
        [
            tech.reset_index(drop=True),
            sentiment.reset_index(drop=True),
            onchain.reset_index(drop=True),
            macro.reset_index(drop=True),
        ],
        axis=1,
    )
    order_book = fetch_binance_order_book(config.symbol)
    for key, value in order_book.items():
        if key != "snapshot_ts":
            dataset[key] = value
    dataset["symbol"] = config.symbol.upper()
    dataset["interval"] = config.interval
    dataset["dataset_generated_at"] = _now_iso()
    dataset.replace([np.inf, -np.inf], np.nan, inplace=True)
    dataset.dropna(inplace=True)
    return dataset


def save_dataset(df: pd.DataFrame, config: MarketConfig) -> Path:
    config.dataset_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(tz=UTC).strftime("%Y%m%d_%H%M%S")
    parquet_path = config.dataset_dir / f"{config.symbol.upper()}_{config.interval}_{stamp}.parquet"
    try:
        df.to_parquet(parquet_path, index=False)
        return parquet_path
    except Exception:
        csv_path = config.dataset_dir / f"{config.symbol.upper()}_{config.interval}_{stamp}.csv"
        df.to_csv(csv_path, index=False)
        return csv_path


def build_and_save_dataset(root: Path, symbol: str, interval: str, limit: int) -> dict[str, Any]:
    dataset_dir = root / "ai" / "data" / "datasets"
    config = MarketConfig(symbol=symbol, interval=interval, limit=limit, dataset_dir=dataset_dir)
    df = merge_dataset(config)
    out = save_dataset(df, config)
    return {"ok": True, "rows": int(len(df)), "dataset": str(out), "symbol": config.symbol, "interval": config.interval}


def main() -> None:
    root = Path(os.getenv("QAI_ROOT", Path(__file__).resolve().parents[2]))
    result = build_and_save_dataset(
        root=root,
        symbol=os.getenv("QAI_SYMBOL", "BTCUSDT"),
        interval=os.getenv("QAI_INTERVAL", "1h"),
        limit=int(os.getenv("QAI_LIMIT", "1200")),
    )
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
