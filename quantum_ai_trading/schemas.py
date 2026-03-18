from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class TrainingArtifact:
    model_name: str
    symbol: str
    interval: str
    trained_at: str
    features: list[str]
    metrics: dict[str, float]
    model_path: str
    scaler_path: str | None = None
    notes: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class SignalDecision:
    symbol: str
    interval: str
    action: str
    confidence: float
    expected_return: float
    stop_loss_pct: float
    take_profit_pct: float
    leverage: float
    reason: str
    feature_snapshot: dict[str, float]
    risk_flags: list[str] = field(default_factory=list)
    model_version: str = "unknown"
    mode: str = "paper"


@dataclass(slots=True)
class GridPlan:
    symbol: str
    lower_price: float
    upper_price: float
    grid_count: int
    capital: float
    leverage: float
    per_grid_capital: float
    spacing_pct: float
    expected_cycle_return_pct: float
    stop_mode: str
    notes: list[str] = field(default_factory=list)
