from __future__ import annotations

import json
import math
import time
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
import requests

from .config import QuantumAITradingConfig


class MarketDataCollector:
    def __init__(self, config: QuantumAITradingConfig):
        self.config = config

    def build_synthetic_klines(
        self,
        symbol: str | None = None,
        interval: str | None = None,
        limit: int | None = None,
    ) -> pd.DataFrame:
        symbol = symbol or self.config.symbol
        interval = interval or self.config.interval
        limit = int(limit or self.config.lookback_limit)
        freq = "1h"
        if interval.endswith("m"):
            freq = f"{int(interval[:-1])}min"
        elif interval.endswith("h"):
            freq = f"{int(interval[:-1])}h"
        elif interval.endswith("d"):
            freq = f"{int(interval[:-1])}d"

        end = pd.Timestamp.utcnow().floor("min")
        open_time = pd.date_range(end=end, periods=limit, freq=freq, tz="UTC")
        base = np.linspace(0, 10 * math.pi, limit)
        trend = np.linspace(0, max(1.0, limit / 500.0), limit)
        close = 50000 + (np.sin(base) * 1500) + (np.cos(base / 3.0) * 900) + trend * 250
        open_ = close * (1 + np.sin(base / 7.0) * 0.0015)
        high = np.maximum(open_, close) * (1.0 + 0.003)
        low = np.minimum(open_, close) * (1.0 - 0.003)
        volume = 250 + np.abs(np.sin(base * 1.5)) * 120 + trend * 15
        quote_asset_volume = volume * close
        trades = (volume * 8).astype(int)
        taker_buy_base = volume * 0.52
        taker_buy_quote = taker_buy_base * close

        df = pd.DataFrame(
            {
                "open_time": open_time,
                "open": open_,
                "high": high,
                "low": low,
                "close": close,
                "volume": volume,
                "close_time": open_time,
                "quote_asset_volume": quote_asset_volume,
                "number_of_trades": trades,
                "taker_buy_base": taker_buy_base,
                "taker_buy_quote": taker_buy_quote,
                "ignore": 0,
                "symbol": symbol.upper(),
                "interval": interval,
            }
        )
        return df

    def fetch_binance_klines(
        self,
        symbol: str | None = None,
        interval: str | None = None,
        limit: int | None = None,
    ) -> pd.DataFrame:
        symbol = symbol or self.config.symbol
        interval = interval or self.config.interval
        limit = limit or self.config.lookback_limit
        url = "https://api.binance.com/api/v3/klines"
        params = {"symbol": symbol.upper(), "interval": interval, "limit": int(limit)}
        try:
            response = requests.get(url, params=params, timeout=self.config.api_timeout)
            response.raise_for_status()
            payload = response.json()
        except Exception:
            return self.build_synthetic_klines(symbol=symbol, interval=interval, limit=limit)

        columns = [
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
        df = pd.DataFrame(payload, columns=columns)
        numeric_cols = [
            "open",
            "high",
            "low",
            "close",
            "volume",
            "quote_asset_volume",
            "number_of_trades",
            "taker_buy_base",
            "taker_buy_quote",
        ]
        for col in numeric_cols:
            df[col] = pd.to_numeric(df[col], errors="coerce")
        df["open_time"] = pd.to_datetime(df["open_time"], unit="ms", utc=True)
        df["close_time"] = pd.to_datetime(df["close_time"], unit="ms", utc=True)
        df["symbol"] = symbol.upper()
        df["interval"] = interval
        return df

    def load_or_fetch_market(self, cache_name: str = "market.parquet") -> pd.DataFrame:
        cache_path = self.config.cache_dir / cache_name
        if cache_path.exists():
            try:
                return pd.read_parquet(cache_path)
            except Exception:
                pass
        df = self.fetch_binance_klines()
        df.to_parquet(cache_path, index=False)
        return df


class OnChainCollector:
    def __init__(self, config: QuantumAITradingConfig):
        self.config = config

    def build_proxy_metrics(self, market_df: pd.DataFrame) -> pd.DataFrame:
        df = market_df[["open_time", "volume", "number_of_trades", "close"]].copy()
        active = df["number_of_trades"].rolling(24).mean().bfill() * 3.1
        transfer = (df["close"] * df["volume"]).rolling(12).mean().bfill()
        miner = (df["volume"].pct_change().fillna(0.0) * -1.0).rolling(6).mean().fillna(0.0)
        staking = (
            1.0
            / (1.0 + np.exp(-df["volume"].pct_change().replace([np.inf, -np.inf], 0.0).fillna(0.0)))
        ).rolling(12).mean().fillna(0.5)
        return pd.DataFrame(
            {
                "open_time": df["open_time"],
                "active_addresses_proxy": active.clip(lower=0.0),
                "transfer_value_proxy": transfer,
                "miner_sell_pressure_proxy": miner,
                "staking_ratio_proxy": staking,
            }
        )

    def load_or_build(self, market_df: pd.DataFrame, cache_name: str = "onchain_proxy.parquet") -> pd.DataFrame:
        cache_path = self.config.cache_dir / cache_name
        if cache_path.exists():
            try:
                return pd.read_parquet(cache_path)
            except Exception:
                pass
        df = self.build_proxy_metrics(market_df)
        df.to_parquet(cache_path, index=False)
        return df


class NewsSentimentCollector:
    def __init__(self, config: QuantumAITradingConfig):
        self.config = config

    @staticmethod
    def _heuristic_sentiment(text: str) -> float:
        positive_words = {
            "approve",
            "surge",
            "bullish",
            "growth",
            "win",
            "record",
            "breakout",
            "adoption",
            "partnership",
            "positive",
            "upgrade",
            "spot etf",
            "buyback",
        }
        negative_words = {
            "ban",
            "hack",
            "exploit",
            "selloff",
            "bearish",
            "lawsuit",
            "liquidation",
            "recession",
            "negative",
            "risk",
            "fraud",
            "shutdown",
            "breach",
            "war",
        }
        lowered = text.lower()
        pos = sum(word in lowered for word in positive_words)
        neg = sum(word in lowered for word in negative_words)
        denom = max(1, pos + neg)
        return float(np.clip((pos - neg) / denom, -1.0, 1.0))

    def synthesize_sentiment_series(self, market_df: pd.DataFrame) -> pd.DataFrame:
        df = market_df[["open_time", "close", "volume"]].copy()
        returns = df["close"].pct_change().fillna(0.0)
        volume_impulse = df["volume"].pct_change().replace([np.inf, -np.inf], 0.0).fillna(0.0)
        sentiment = (
            returns.rolling(4).mean().fillna(0.0) * 8.0
            + volume_impulse.rolling(4).mean().fillna(0.0) * 2.0
        )
        return pd.DataFrame(
            {
                "open_time": df["open_time"],
                "sentiment_index": sentiment.clip(-1.0, 1.0),
                "headline_score": sentiment.rolling(3).mean().fillna(0.0).clip(-1.0, 1.0),
            }
        )

    def load_or_build(self, market_df: pd.DataFrame, cache_name: str = "sentiment_proxy.parquet") -> pd.DataFrame:
        cache_path = self.config.cache_dir / cache_name
        if cache_path.exists():
            try:
                return pd.read_parquet(cache_path)
            except Exception:
                pass
        df = self.synthesize_sentiment_series(market_df)
        df.to_parquet(cache_path, index=False)
        return df


class MacroCollector:
    def __init__(self, config: QuantumAITradingConfig):
        self.config = config

    def synthesize_macro_series(self, market_df: pd.DataFrame) -> pd.DataFrame:
        df = market_df[["open_time", "close"]].copy()
        base_wave = np.sin(np.linspace(0, 12 * math.pi, len(df)))
        rate_shock = np.cos(np.linspace(0, 4 * math.pi, len(df))) * 0.3
        inflation_proxy = pd.Series(base_wave + rate_shock, index=df.index).rolling(8).mean().fillna(0.0)
        return pd.DataFrame(
            {
                "open_time": df["open_time"],
                "macro_risk_index": inflation_proxy.clip(-1.0, 1.0),
                "dxy_proxy": (
                    1.0 - df["close"].pct_change().fillna(0.0).rolling(24).mean().fillna(0.0) * 20.0
                ).clip(0.7, 1.3),
            }
        )

    def load_or_build(self, market_df: pd.DataFrame, cache_name: str = "macro_proxy.parquet") -> pd.DataFrame:
        cache_path = self.config.cache_dir / cache_name
        if cache_path.exists():
            try:
                return pd.read_parquet(cache_path)
            except Exception:
                pass
        df = self.synthesize_macro_series(market_df)
        df.to_parquet(cache_path, index=False)
        return df


def save_json(path: str | Path, payload: dict[str, Any]) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def now_ts() -> int:
    return int(time.time())
