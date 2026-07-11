#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
COMPOSE_FILE="$REPO/compose.yml"
LOG_DIR="$REPO/_logs/compose_repair"
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_DIR"

OUT="$LOG_DIR/${TS}_compose_precheck.log"
docker compose -f "$COMPOSE_FILE" -p quantumai-stack config > "$OUT" 2>&1

{
  echo "COMPOSE_PRECHECK=OK"
  echo "LOG=$OUT"
} | tee "$LOG_DIR/${TS}_compose_precheck_report.log"
