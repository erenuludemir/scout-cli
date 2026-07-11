#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
COMPOSE_MAIN="$REPO/compose.yml"
COMPOSE_OVERRIDE="$REPO/ops/compose.hardening.override.yml"
PROJECT="quantumai-stack"
TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="$REPO/_logs/hardening"
mkdir -p "$LOG_DIR" "$REPO/_backups"
cp "$COMPOSE_MAIN" "$REPO/_backups/compose.yml.$TS.bak"

docker compose -f "$COMPOSE_MAIN" -f "$COMPOSE_OVERRIDE" -p "$PROJECT" config > "$LOG_DIR/compose_merged_$TS.yml"
docker compose -f "$COMPOSE_MAIN" -f "$COMPOSE_OVERRIDE" -p "$PROJECT" up -d prometheus postgres-exporter demo-app-redpanda mcai-redpanda gli gli-mainnet gli-sepolia watchtower | tee "$LOG_DIR/compose_apply_$TS.log"
docker compose -f "$COMPOSE_MAIN" -f "$COMPOSE_OVERRIDE" -p "$PROJECT" ps | tee -a "$LOG_DIR/compose_apply_$TS.log"

echo "MERGED=$LOG_DIR/compose_merged_$TS.yml"
echo "LOG=$LOG_DIR/compose_apply_$TS.log"
