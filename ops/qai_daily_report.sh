#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
OUT="$ROOT/_reports/managerai/daily_$(date +%Y%m%d).md"

mkdir -p "$ROOT/_reports/managerai"

{
  echo "# Daily ManagerAI Report"
  echo
  date -u +"UTC: %Y-%m-%d %H:%M:%S"
  echo
  echo "## Diagnose"
  echo
  bash "$ROOT/ops/qai_manager_ai.sh" diagnose --json || true
  echo
  echo "## Autopilot"
  echo
  bash "$ROOT/ops/qai_manager_ai.sh" autopilot --json || true
  echo
  echo "## Broker"
  echo
  curl -fsS http://127.0.0.1:8787/health || true
  echo
} >"$OUT"

cat "$OUT"
