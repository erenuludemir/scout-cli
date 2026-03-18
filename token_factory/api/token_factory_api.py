#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="QuantumAI Token Factory API", version="1.0.0")
ROOT = Path(os.getenv("QAI_ROOT", Path(__file__).resolve().parents[2]))
PYTHON_BIN = os.getenv("QAI_PYTHON", sys.executable)


class CompileRequest(BaseModel):
    network: str = Field(default="erc20")


class DeployRequest(BaseModel):
    network: str = Field(default="erc20")


class DistributionRow(BaseModel):
    address: str
    amount: int


class DistributionRequest(BaseModel):
    network: str = Field(default="erc20")
    rows: list[DistributionRow]


def run_py(script: Path, env: dict[str, str] | None = None) -> dict[str, Any]:
    merged = os.environ.copy()
    if env:
        merged.update(env)
    proc = subprocess.run([PYTHON_BIN, str(script)], cwd=str(ROOT), env=merged, capture_output=True, text=True)
    if proc.returncode != 0:
        raise HTTPException(status_code=500, detail={"stderr": proc.stderr, "stdout": proc.stdout, "code": proc.returncode})
    out = proc.stdout.strip().splitlines()
    if not out:
        return {"ok": True}
    try:
        return json.loads(out[-1])
    except Exception:
        return {"ok": True, "stdout": out}


@app.get("/health")
def health() -> dict[str, Any]:
    return {"ok": True, "service": "token-factory-api", "root": str(ROOT)}


@app.post("/compile")
def compile_contract(req: CompileRequest) -> dict[str, Any]:
    return run_py(
        ROOT / "token_factory" / "scripts" / "compile_token.py",
        env={"TOKEN_CHAIN_TYPE": req.network.lower()},
    )


@app.post("/deploy")
def deploy(req: DeployRequest) -> dict[str, Any]:
    if req.network.lower() == "erc20":
        return run_py(ROOT / "token_factory" / "scripts" / "deploy_erc20.py")
    if req.network.lower() == "trc20":
        return run_py(ROOT / "token_factory" / "scripts" / "deploy_trc20.py", env={"TOKEN_CHAIN_TYPE": "trc20"})
    raise HTTPException(status_code=400, detail="invalid_network")


@app.post("/distribute")
def distribute(req: DistributionRequest) -> dict[str, Any]:
    plan_path = ROOT / "token_factory" / "distributions" / "api_distribution.csv"
    with plan_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["address", "amount"])
        writer.writeheader()
        for row in req.rows:
            writer.writerow({"address": row.address, "amount": row.amount})

    env = {"TOKEN_DISTRIBUTION_CSV": str(plan_path), "TOKEN_CHAIN_TYPE": req.network.lower()}
    if req.network.lower() == "erc20":
        return run_py(ROOT / "token_factory" / "scripts" / "distribute_erc20.py", env=env)
    if req.network.lower() == "trc20":
        return run_py(ROOT / "token_factory" / "scripts" / "distribute_trc20.py", env=env)
    raise HTTPException(status_code=400, detail="invalid_network")


@app.post("/verify")
def verify(req: DeployRequest) -> dict[str, Any]:
    return run_py(
        ROOT / "token_factory" / "scripts" / "verify_local_contract_state.py",
        env={"TOKEN_CHAIN_TYPE": req.network.lower()},
    )
