#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

import pandas as pd

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from ai.quantum.quantum_optimizer import monte_carlo_stop_take, quantum_inspired_optimize


def load_latest_dataset(dataset_dir: Path) -> pd.DataFrame:
    files = sorted(dataset_dir.glob("*"))
    if not files:
        raise FileNotFoundError(f"dataset_not_found:{dataset_dir}")
    latest = files[-1]
    if latest.suffix == ".parquet":
        return pd.read_parquet(latest)
    return pd.read_csv(latest)


def leverage_recommendation(df: pd.DataFrame, account_equity: float, risk_pct: float) -> dict[str, float]:
    current = float(df["close"].iloc[-1])
    vol = float(df["close"].pct_change().rolling(24).std().iloc[-1] or 0.01)
    atr = float(df["atr_14"].iloc[-1] or current * 0.01)
    rsi = float(df["rsi_14"].iloc[-1] or 50.0)
    base = 5.0
    if vol > 0.03:
        base = 2.0
    elif vol > 0.02:
        base = 3.0
    elif vol > 0.01:
        base = 4.0
    if rsi > 75 or rsi < 25:
        base = min(base, 2.0)
    stop_distance = max(atr * 1.2, current * 0.008)
    risk_amount = account_equity * risk_pct
    position_notional = risk_amount / max(stop_distance / current, 1e-6)
    leverage = int(max(1, min(10, round(base))))
    size_with_leverage = position_notional * leverage
    return {
        "recommended_leverage": leverage,
        "volatility": vol,
        "atr": atr,
        "stop_distance": stop_distance,
        "risk_amount": risk_amount,
        "position_notional": position_notional,
        "size_with_leverage": size_with_leverage,
    }


def grid_plan(df: pd.DataFrame) -> dict[str, float]:
    current = float(df["close"].iloc[-1])
    out = quantum_inspired_optimize(df, current)
    out.update(monte_carlo_stop_take(df, current))
    out["grid_step"] = (out["upper"] - out["lower"]) / max(out["grid_count"], 1)
    out["mode"] = "GRID"
    return out


def hybrid_strategy(df: pd.DataFrame, account_equity: float, risk_pct: float) -> dict[str, Any]:
    lev = leverage_recommendation(df, account_equity=account_equity, risk_pct=risk_pct)
    grid = grid_plan(df)
    trend_strength = float(df["adx_14"].iloc[-1] or 0.0)
    if trend_strength >= 25 and abs(float(df["macd_diff"].iloc[-1] or 0.0)) > 0.0:
        mode = "TREND_LEVERAGE"
        summary = "trend_guclu_grid_daralt_or_pause"
    else:
        mode = "GRID"
        summary = "yatay_veya_dalgali_pazar_grid_uygun"
    return {"ok": True, "mode": mode, "summary": summary, "leverage": lev, "grid": grid}


def build_strategy_plan(root: Path, account_equity: float, risk_pct: float) -> dict[str, Any]:
    dataset_dir = root / "ai" / "data" / "datasets"
    models_dir = root / "ai" / "models"
    models_dir.mkdir(parents=True, exist_ok=True)
    df = load_latest_dataset(dataset_dir)
    plan = hybrid_strategy(df, account_equity=account_equity, risk_pct=risk_pct)
    out = models_dir / "grid_leverage_plan.json"
    out.write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
    return plan


def main() -> None:
    root = Path(os.getenv("QAI_ROOT", Path(__file__).resolve().parents[2]))
    plan = build_strategy_plan(
        root=root,
        account_equity=float(os.getenv("QAI_ACCOUNT_EQUITY", "10000")),
        risk_pct=float(os.getenv("QAI_RISK_PCT", "0.01")),
    )
    print(json.dumps(plan, ensure_ascii=False))


if __name__ == "__main__":
    main()
