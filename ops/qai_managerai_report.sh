#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
STAMP="$(date +%Y%m%d_%H%M%S)"
OUT_JSON="$ROOT/_reports/managerai/manual_${STAMP}.json"
OUT_MD="$ROOT/_reports/managerai/manual_${STAMP}.md"

mkdir -p "$ROOT/_reports/managerai"
cd "$ROOT"

bash "$ROOT/ops/qai_manager_ai.sh" diagnose --json >"$OUT_JSON"
python3 - "$OUT_JSON" "$OUT_MD" <<'PY'
import json
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
payload = json.loads(src.read_text(encoding="utf-8"))

lines = ["# Manual ManagerAI Report", ""]
lines.append(f"- status: {payload.get('status')}")
lines.append(f"- service_count: {payload.get('service_count')}")
lines.append("")
lines.append("| service | status | score | risk | action |")
lines.append("|---|---|---:|---|---|")
for item in payload.get("services", []):
    lines.append(
        f"| {item.get('service', '-')} | {item.get('status', '-')} | "
        f"{item.get('quantum_score', '-')} | {item.get('risk_level', '-')} | "
        f"{item.get('recommended_action', '-')} |"
    )
lines.append("")
lines.append("```json")
lines.append(json.dumps(payload, ensure_ascii=False, indent=2))
lines.append("```")
dst.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(src)
print(dst)
PY
cat "$OUT_JSON"
