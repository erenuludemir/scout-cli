from __future__ import annotations

import math
import random
from dataclasses import dataclass


@dataclass(slots=True)
class AnnealCandidate:
    lower: float
    upper: float
    grid_count: int
    leverage: float
    score: float


def objective(
    lower: float,
    upper: float,
    grid_count: int,
    leverage: float,
    spot_price: float,
    volatility: float,
) -> float:
    if lower <= 0 or upper <= lower or grid_count < 2 or leverage < 1.0:
        return -1e18
    width_pct = (upper - lower) / spot_price
    spacing_pct = width_pct / max(1, grid_count - 1)
    cycle_gain = max(0.0, spacing_pct * 0.70 * leverage)
    risk_penalty = max(0.0, (volatility * leverage * 2.5) - spacing_pct)
    out_of_range_penalty = abs(((lower + upper) / 2.0) - spot_price) / spot_price
    return cycle_gain - risk_penalty - out_of_range_penalty * 0.35 - max(0.0, leverage - 3.0) * 0.02


def quantum_inspired_grid_search(
    spot_price: float,
    volatility: float,
    min_grid: int,
    max_grid: int,
    max_leverage: float,
    iterations: int = 250,
) -> AnnealCandidate:
    span = max(spot_price * max(0.02, volatility * 10.0), spot_price * 0.03)
    current = AnnealCandidate(
        lower=max(spot_price - span, 0.0001),
        upper=spot_price + span,
        grid_count=max(min_grid, 10),
        leverage=min(max_leverage, 2.0),
        score=0.0,
    )
    current.score = objective(
        current.lower,
        current.upper,
        current.grid_count,
        current.leverage,
        spot_price,
        volatility,
    )
    best = current
    temp = 1.0

    for _ in range(iterations):
        proposal_lower = max(0.0001, current.lower * (1.0 + random.uniform(-0.05, 0.05)))
        proposal_upper = max(
            current.upper * (1.0 + random.uniform(-0.05, 0.05)),
            proposal_lower + 0.0002,
        )
        proposal = AnnealCandidate(
            lower=proposal_lower,
            upper=proposal_upper,
            grid_count=max(min_grid, min(max_grid, current.grid_count + random.randint(-2, 2))),
            leverage=max(1.0, min(max_leverage, current.leverage + random.uniform(-0.35, 0.35))),
            score=0.0,
        )
        proposal.score = objective(
            proposal.lower,
            proposal.upper,
            proposal.grid_count,
            proposal.leverage,
            spot_price,
            volatility,
        )
        delta = proposal.score - current.score
        if delta > 0 or math.exp(delta / max(0.0001, temp)) > random.random():
            current = proposal
        if current.score > best.score:
            best = current
        temp *= 0.992

    return best
