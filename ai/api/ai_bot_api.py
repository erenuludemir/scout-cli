#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="QuantumAI Bot API", version="1.0.0")
ROOT = Path(os.getenv("QAI_ROOT", Path(__file__).resolve().parents[2]))
PYTHON_BIN = os.getenv("QAI_PYTHON", sys.executable)


class DatasetRequest(BaseModel):
    symbol: str = Field(default="BTCUSDT")
    interval: str = Field(default="1h")
    limit: int = Field(default=1200)


class StrategyRequest(BaseModel):
    account_equity: float = Field(default=10000.0)
    risk_pct: float = Field(default=0.01)


def run_py(module_path: Path, env: dict[str, str] | None = None) -> dict[str, Any]:
    merged = os.environ.copy()
    if env:
        merged.update(env)
    proc = subprocess.run([PYTHON_BIN, str(module_path)], cwd=str(ROOT), env=merged, capture_output=True, text=True)
    stdout = proc.stdout.strip().splitlines()
    stderr = proc.stderr.strip()
    if proc.returncode != 0:
        raise HTTPException(status_code=500, detail={"returncode": proc.returncode, "stderr": stderr, "stdout": stdout})
    if not stdout:
        return {"ok": True}
    try:
        return json.loads(stdout[-1])
    except Exception:
        return {"ok": True, "stdout": stdout, "stderr": stderr}


@app.get("/health")
def health() -> dict[str, Any]:
    return {"ok": True, "service": "quantumai-bot-api", "root": str(ROOT)}


@app.post("/dataset/build")
def dataset_build(req: DatasetRequest) -> dict[str, Any]:
    return run_py(
        ROOT / "ai" / "data" / "market_data_pipeline.py",
        env={"QAI_SYMBOL": req.symbol, "QAI_INTERVAL": req.interval, "QAI_LIMIT": str(req.limit)},
    )


@app.post("/train/supervised")
def train_supervised() -> dict[str, Any]:
    return run_py(ROOT / "ai" / "training" / "supervised_trainer.py")


@app.post("/train/rl")
def train_rl() -> dict[str, Any]:
    return run_py(ROOT / "ai" / "training" / "reinforcement_trainer.py")


@app.get("/signal/latest")
def signal_latest() -> dict[str, Any]:
    return run_py(ROOT / "ai" / "signals" / "signal_engine.py")


@app.post("/strategy/grid-leverage")
def strategy_grid_leverage(req: StrategyRequest) -> dict[str, Any]:
    return run_py(
        ROOT / "ai" / "strategies" / "grid_leverage_engine.py",
        env={"QAI_ACCOUNT_EQUITY": str(req.account_equity), "QAI_RISK_PCT": str(req.risk_pct)},
    )
