from __future__ import annotations

from dataclasses import asdict
from pathlib import Path

from fastapi import APIRouter, Query

from .config import QuantumAITradingConfig
from .grid_leverage_engine import GridLeverageEngine
from .signal_engine import SignalEngine
from .trainer import train_all

router = APIRouter(prefix="/quantum-ai", tags=["quantum-ai"])


def _cfg() -> QuantumAITradingConfig:
    return QuantumAITradingConfig(root_dir=Path.cwd())


@router.get("/health")
def health() -> dict:
    cfg = _cfg()
    return {
        "ok": True,
        "service": "quantum-ai-trading",
        "symbol": cfg.symbol,
        "interval": cfg.interval,
        "paper_trading_only": cfg.paper_trading_only,
    }


@router.post("/train")
def train() -> dict:
    cfg = _cfg()
    return train_all(cfg)


@router.get("/signal")
def signal() -> dict:
    cfg = _cfg()
    decision = SignalEngine(cfg).generate()
    return asdict(decision)


@router.get("/grid-plan")
def grid_plan(capital: float = Query(default=1000.0, ge=10.0)) -> dict:
    cfg = _cfg()
    plan = GridLeverageEngine(cfg).recommend(capital=capital)
    return asdict(plan)


@router.get("/leverage")
def leverage() -> dict:
    cfg = _cfg()
    return GridLeverageEngine(cfg).leverage_recommendation()
