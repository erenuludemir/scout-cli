#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from dataclasses import asdict
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from quantum_ai_trading.config import QuantumAITradingConfig
from quantum_ai_trading.grid_leverage_engine import GridLeverageEngine


def main() -> None:
    capital = float(sys.argv[1]) if len(sys.argv) > 1 else 1000.0
    cfg = QuantumAITradingConfig(root_dir=Path.cwd())
    plan = GridLeverageEngine(cfg).recommend(capital=capital)
    print(json.dumps(asdict(plan), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
