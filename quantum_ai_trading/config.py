from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path


def _env(name: str, default: str) -> str:
    value = os.getenv(name)
    return value if value not in (None, "") else default


def _env_int(name: str, default: int) -> int:
    try:
        return int(_env(name, str(default)))
    except Exception:
        return default


def _env_float(name: str, default: float) -> float:
    try:
        return float(_env(name, str(default)))
    except Exception:
        return default


def _env_bool(name: str, default: bool) -> bool:
    raw = _env(name, "1" if default else "0").strip().lower()
    return raw in {"1", "true", "yes", "on"}


@dataclass(slots=True)
class QuantumAITradingConfig:
    root_dir: Path = field(default_factory=lambda: Path(os.getenv("QAI_TRADING_ROOT", ".")).resolve())
    data_dir: Path = field(init=False)
    model_dir: Path = field(init=False)
    cache_dir: Path = field(init=False)
    signal_dir: Path = field(init=False)

    symbol: str = field(default_factory=lambda: _env("QAI_SYMBOL", "BTCUSDT"))
    interval: str = field(default_factory=lambda: _env("QAI_INTERVAL", "1h"))
    lookback_limit: int = field(default_factory=lambda: _env_int("QAI_LOOKBACK_LIMIT", 2000))
    label_horizon: int = field(default_factory=lambda: _env_int("QAI_LABEL_HORIZON", 12))
    classification_threshold_up: float = field(default_factory=lambda: _env_float("QAI_THRESHOLD_UP", 0.004))
    classification_threshold_down: float = field(default_factory=lambda: _env_float("QAI_THRESHOLD_DOWN", -0.004))
    min_signal_confidence: float = field(default_factory=lambda: _env_float("QAI_MIN_SIGNAL_CONFIDENCE", 0.58))
    paper_trading_only: bool = field(default_factory=lambda: _env_bool("QAI_PAPER_ONLY", True))
    max_leverage: float = field(default_factory=lambda: _env_float("QAI_MAX_LEVERAGE", 5.0))
    min_leverage: float = field(default_factory=lambda: _env_float("QAI_MIN_LEVERAGE", 1.0))
    sentiment_weight: float = field(default_factory=lambda: _env_float("QAI_SENTIMENT_WEIGHT", 0.12))
    onchain_weight: float = field(default_factory=lambda: _env_float("QAI_ONCHAIN_WEIGHT", 0.10))
    macro_weight: float = field(default_factory=lambda: _env_float("QAI_MACRO_WEIGHT", 0.08))
    quantum_iterations: int = field(default_factory=lambda: _env_int("QAI_QUANTUM_ITERATIONS", 250))
    grid_min_count: int = field(default_factory=lambda: _env_int("QAI_GRID_MIN_COUNT", 6))
    grid_max_count: int = field(default_factory=lambda: _env_int("QAI_GRID_MAX_COUNT", 30))
    grid_default_capital: float = field(default_factory=lambda: _env_float("QAI_GRID_CAPITAL", 1000.0))
    api_timeout: float = field(default_factory=lambda: _env_float("QAI_API_TIMEOUT", 20.0))

    def __post_init__(self) -> None:
        self.data_dir = self.root_dir / "data"
        self.model_dir = self.root_dir / "models"
        self.cache_dir = self.root_dir / "cache"
        self.signal_dir = self.root_dir / "signals"
        for path in (self.data_dir, self.model_dir, self.cache_dir, self.signal_dir):
            path.mkdir(parents=True, exist_ok=True)
