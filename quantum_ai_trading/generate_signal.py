#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from dataclasses import asdict
from pathlib import Path

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from quantum_ai_trading.config import QuantumAITradingConfig
from quantum_ai_trading.signal_engine import SignalEngine


def main() -> None:
    cfg = QuantumAITradingConfig(root_dir=Path.cwd())
    signal = SignalEngine(cfg).generate()
    print(json.dumps(asdict(signal), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
