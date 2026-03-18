#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from integrations.linear.linear_client import LinearClient


def load_signal(root: Path, signal_path: str | None = None) -> dict[str, Any]:
    path = Path(signal_path).expanduser().resolve() if signal_path else root / "ai" / "models" / "latest_signal.json"
    return json.loads(path.read_text(encoding="utf-8"))


def build_issue_title(signal: dict[str, Any]) -> str:
    symbol = str(signal.get("symbol", "UNKNOWN"))
    action = str(signal.get("signal", "HOLD"))
    confidence = float(signal.get("confidence", 0.0)) * 100.0
    return f"AI Signal {symbol}: {action} ({confidence:.2f}%)"


def build_issue_description(signal: dict[str, Any]) -> str:
    probabilities = signal.get("probabilities", {}) or {}
    reasons = signal.get("reasons", []) or []
    risk = signal.get("risk", {}) or {}
    generated_at = datetime.now(timezone.utc).isoformat()
    reason_lines = "\n".join(f"- {reason}" for reason in reasons) if reasons else "- No reasons provided"
    probability_lines = "\n".join(f"- {name}: {value}" for name, value in probabilities.items()) if probabilities else "- No probabilities"
    risk_lines = "\n".join(f"- {name}: {value}" for name, value in risk.items()) if risk else "- No risk data"
    return (
        "## QuantumAI Signal Summary\n"
        f"- Symbol: {signal.get('symbol', 'UNKNOWN')}\n"
        f"- Interval: {signal.get('interval', 'UNKNOWN')}\n"
        f"- Signal: {signal.get('signal', 'HOLD')}\n"
        f"- Confidence: {signal.get('confidence', 0.0)}\n"
        f"- Price: {signal.get('price', 0.0)}\n"
        f"- Stop Loss: {signal.get('stop_loss', 0.0)}\n"
        f"- Take Profit: {signal.get('take_profit', 0.0)}\n"
        f"- Generated At: {generated_at}\n\n"
        "## Reasons\n"
        f"{reason_lines}\n\n"
        "## Probabilities\n"
        f"{probability_lines}\n\n"
        "## Risk\n"
        f"{risk_lines}\n"
    )


def push_signal_to_linear(
    *,
    root: Path | None = None,
    signal_path: str | None = None,
    team_id: str | None = None,
    team_key: str | None = None,
    team_name: str | None = None,
    priority: int | None = None,
) -> dict[str, Any]:
    base_root = root or Path(os.getenv("QAI_ROOT", Path(__file__).resolve().parents[2]))
    signal = load_signal(base_root, signal_path=signal_path)
    client = LinearClient()
    issue = client.create_issue(
        title=build_issue_title(signal),
        description=build_issue_description(signal),
        team_id=team_id,
        team_key=team_key,
        team_name=team_name,
        priority=priority,
    )
    payload = {
        "ok": True,
        "signal": signal,
        "issue": issue,
    }
    out = base_root / "ai" / "models" / "latest_linear_issue.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return payload


def main() -> None:
    result = push_signal_to_linear(
        team_id=os.getenv("LINEAR_TEAM_ID") or None,
        team_key=os.getenv("LINEAR_TEAM_KEY") or None,
        team_name=os.getenv("LINEAR_TEAM_NAME") or None,
        priority=int(os.getenv("LINEAR_ISSUE_PRIORITY", "0")) or None,
        signal_path=os.getenv("LINEAR_SIGNAL_FILE") or None,
    )
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
