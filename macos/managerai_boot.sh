#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
LOG_DIR="$ROOT/_logs/managerai"
REPORT_DIR="$ROOT/_reports/managerai"

mkdir -p "$LOG_DIR" "$REPORT_DIR" "$ROOT/_state/managerai"
exec >>"$LOG_DIR/launchd_boot.log" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] managerai_boot start"

export COLIMA_PROFILE="${COLIMA_PROFILE:-mcai-colima}"
export DOCKER_HOST="${DOCKER_HOST:-unix://$HOME/.colima/${COLIMA_PROFILE}/docker.sock}"

cd "$ROOT"

if command -v colima >/dev/null 2>&1; then
  colima start --profile "$COLIMA_PROFILE" >/dev/null 2>&1 || true
fi

bash "$ROOT/ops/qai_managerai_stack.sh" up -d managerai managerai-broker managerai-guard
bash "$ROOT/ops/qai_manager_ai.sh" diagnose --json >"$REPORT_DIR/boot_diagnose.json" || true

echo "[$(date '+%Y-%m-%d %H:%M:%S')] managerai_boot done"
