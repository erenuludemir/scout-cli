from __future__ import annotations

import numpy as np
import pandas as pd


def rsi(series: pd.Series, window: int = 14) -> pd.Series:
    delta = series.diff()
    gain = delta.clip(lower=0.0).rolling(window).mean()
    loss = (-delta.clip(upper=0.0)).rolling(window).mean()
    rs = gain / loss.replace(0.0, np.nan)
    out = 100 - (100 / (1 + rs))
    return out.fillna(50.0)


def ema(series: pd.Series, span: int) -> pd.Series:
    return series.ewm(span=span, adjust=False).mean()


def macd(series: pd.Series) -> tuple[pd.Series, pd.Series, pd.Series]:
    fast = ema(series, 12)
    slow = ema(series, 26)
    macd_line = fast - slow
    signal_line = ema(macd_line, 9)
    hist = macd_line - signal_line
    return macd_line, signal_line, hist


def bollinger(
    series: pd.Series,
    window: int = 20,
    std_mult: float = 2.0,
) -> tuple[pd.Series, pd.Series, pd.Series]:
    ma = series.rolling(window).mean()
    std = series.rolling(window).std().fillna(0.0)
    upper = ma + std * std_mult
    lower = ma - std * std_mult
    return lower, ma, upper


def atr(df: pd.DataFrame, window: int = 14) -> pd.Series:
    high_low = df["high"] - df["low"]
    high_close = (df["high"] - df["close"].shift()).abs()
    low_close = (df["low"] - df["close"].shift()).abs()
    tr = pd.concat([high_low, high_close, low_close], axis=1).max(axis=1)
    return tr.rolling(window).mean().bfill()


def add_technical_features(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    out["ret_1"] = out["close"].pct_change().fillna(0.0)
    out["ret_4"] = out["close"].pct_change(4).fillna(0.0)
    out["ret_12"] = out["close"].pct_change(12).fillna(0.0)
    out["ret_24"] = out["close"].pct_change(24).fillna(0.0)
    out["vol_chg_1"] = out["volume"].pct_change().replace([np.inf, -np.inf], 0.0).fillna(0.0)
    out["volatility_12"] = out["ret_1"].rolling(12).std().fillna(0.0)
    out["volatility_24"] = out["ret_1"].rolling(24).std().fillna(0.0)
    out["rsi_14"] = rsi(out["close"], 14)
    out["ema_12"] = ema(out["close"], 12)
    out["ema_26"] = ema(out["close"], 26)
    out["ema_cross"] = (out["ema_12"] - out["ema_26"]) / out["close"].replace(0.0, np.nan)
    macd_line, signal_line, hist = macd(out["close"])
    out["macd_line"] = macd_line
    out["macd_signal"] = signal_line
    out["macd_hist"] = hist
    bb_low, bb_mid, bb_up = bollinger(out["close"])
    out["bb_low"] = bb_low
    out["bb_mid"] = bb_mid
    out["bb_up"] = bb_up
    out["bb_width"] = (bb_up - bb_low) / out["close"].replace(0.0, np.nan)
    out["atr_14"] = atr(out, 14)
    rolling_high = out["high"].rolling(55).max()
    rolling_low = out["low"].rolling(55).min()
    fib_range = (rolling_high - rolling_low).replace(0.0, np.nan)
    out["fib_236"] = rolling_high - fib_range * 0.236
    out["fib_382"] = rolling_high - fib_range * 0.382
    out["fib_618"] = rolling_high - fib_range * 0.618
    out["distance_to_fib_382"] = (out["close"] - out["fib_382"]) / out["close"].replace(0.0, np.nan)
    out["distance_to_fib_618"] = (out["close"] - out["fib_618"]) / out["close"].replace(0.0, np.nan)
    out["price_position_55"] = (out["close"] - rolling_low) / (rolling_high - rolling_low).replace(0.0, np.nan)
    out.replace([np.inf, -np.inf], np.nan, inplace=True)
    out.bfill(inplace=True)
    out.ffill(inplace=True)
    out.fillna(0.0, inplace=True)
    return out
