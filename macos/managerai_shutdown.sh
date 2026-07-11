#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
LOG_DIR="$ROOT/_logs/managerai"
REPORT_DIR="$ROOT/_reports/managerai"

mkdir -p "$LOG_DIR" "$REPORT_DIR"
exec >>"$LOG_DIR/shutdown.log" 2>&1

echo "[$(date '+%Y-%m-%d %H:%M:%S')] managerai_shutdown start"

export COLIMA_PROFILE="${COLIMA_PROFILE:-mcai-colima}"
export DOCKER_HOST="${DOCKER_HOST:-unix://$HOME/.colima/${COLIMA_PROFILE}/docker.sock}"

cd "$ROOT"

bash "$ROOT/ops/qai_manager_ai.sh" diagnose --json >"$REPORT_DIR/pre_shutdown_diagnose.json" || true
bash "$ROOT/ops/qai_managerai_stack.sh" stop managerai-guard managerai-broker managerai || true

echo "[$(date '+%Y-%m-%d %H:%M:%S')] managerai_shutdown done"
