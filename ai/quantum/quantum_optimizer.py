#!/usr/bin/env python3
from __future__ import annotations

import itertools
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


@dataclass(slots=True)
class GridSearchSpace:
    lower_multipliers: list[float]
    upper_multipliers: list[float]
    grid_counts: list[int]
    leverage_values: list[int]


def simulate_grid(df: pd.DataFrame, lower: float, upper: float, grids: int, leverage: int = 1) -> dict[str, float]:
    close = df["close"].to_numpy(dtype=float)
    if len(close) < 10 or lower <= 0 or upper <= lower or grids < 2:
        return {"score": -1e9}
    step = (upper - lower) / grids
    levels = [lower + i * step for i in range(grids + 1)]
    pnl = 0.0
    inventory = 0.0
    fills = 0
    max_drawdown = 0.0
    peak = 0.0

    for px in close:
        for i in range(len(levels) - 1):
            lo = levels[i]
            hi = levels[i + 1]
            if lo <= px <= hi:
                center = (lo + hi) / 2.0
                if px <= center:
                    inventory += 1.0
                    pnl -= px
                    fills += 1
                elif inventory > 0:
                    inventory -= 1.0
                    pnl += px
                    fills += 1
                break
        equity = pnl + inventory * px
        peak = max(peak, equity)
        max_drawdown = max(max_drawdown, peak - equity)

    realized = pnl + inventory * close[-1]
    score = (realized * leverage) - (max_drawdown * 0.75) + (fills * 0.001)
    return {
        "score": float(score),
        "realized": float(realized),
        "fills": int(fills),
        "max_drawdown": float(max_drawdown),
        "lower": float(lower),
        "upper": float(upper),
        "grid_count": int(grids),
        "leverage": int(leverage),
    }


def quantum_inspired_optimize(df: pd.DataFrame, current_price: float) -> dict[str, float]:
    rng = np.random.default_rng(7)
    vol = float(df["close"].pct_change().rolling(48).std().iloc[-1] or 0.01)
    base = max(vol * current_price * 12.0, current_price * 0.03)
    search = GridSearchSpace(
        lower_multipliers=[0.85, 0.90, 0.93, 0.95, 0.97],
        upper_multipliers=[1.03, 1.05, 1.07, 1.10, 1.15],
        grid_counts=[8, 10, 12, 16, 20],
        leverage_values=[1, 2, 3, 5],
    )
    candidates = []
    for lm, um, gc, lev in itertools.product(search.lower_multipliers, search.upper_multipliers, search.grid_counts, search.leverage_values):
        lower = max(current_price * lm + rng.normal(0.0, base * 0.02), 0.01)
        upper = max(current_price * um + abs(rng.normal(0.0, base * 0.02)), lower * 1.01)
        candidates.append(simulate_grid(df, lower, upper, gc, leverage=lev))
    best = max(candidates, key=lambda item: item["score"])
    best["volatility_proxy"] = vol
    best["confidence"] = float(np.clip(0.55 + (best["score"] / max(abs(best["score"]) + 1.0, 1.0)) * 0.15, 0.50, 0.95))
    best["reason"] = "quantum_inspired_parameter_search"
    return best


def monte_carlo_stop_take(df: pd.DataFrame, current_price: float, horizon: int = 24, simulations: int = 500) -> dict[str, float]:
    returns = df["close"].pct_change().dropna().tail(500)
    mu = float(returns.mean())
    sigma = float(returns.std() or 0.01)
    rng = np.random.default_rng(9)
    paths = []
    for _ in range(simulations):
        shocks = rng.normal(mu, sigma, horizon)
        paths.append(current_price * np.cumprod(1.0 + shocks)[-1])
    arr = np.array(paths, dtype=float)
    p10, p50, p90 = np.quantile(arr, [0.1, 0.5, 0.9])
    stop_loss = current_price - max((current_price - p10) * 0.8, current_price * 0.01)
    take_profit = current_price + max((p90 - current_price) * 0.8, current_price * 0.012)
    return {"mc_p10": float(p10), "mc_p50": float(p50), "mc_p90": float(p90), "stop_loss": float(stop_loss), "take_profit": float(take_profit)}


def main() -> None:
    root = Path(os.getenv("QAI_ROOT", Path(__file__).resolve().parents[2]))
    files = sorted((root / "ai" / "data" / "datasets").glob("*"))
    if not files:
        raise FileNotFoundError("dataset_missing")
    latest = files[-1]
    df = pd.read_parquet(latest) if latest.suffix == ".parquet" else pd.read_csv(latest)
    price = float(df["close"].iloc[-1])
    out = quantum_inspired_optimize(df, price)
    out.update(monte_carlo_stop_take(df, price))
    target = root / "ai" / "models" / "quantum_grid_plan.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"ok": True, "plan": str(target), **out}, ensure_ascii=False))


if __name__ == "__main__":
    main()
