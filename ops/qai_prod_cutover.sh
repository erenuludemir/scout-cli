#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${COLIMA_PROFILE:-mcai-colima}"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$ROOT/_runtime_backups/$STAMP"
mkdir -p "$BACKUP_DIR"

export DOCKER_HOST="${DOCKER_HOST:-unix://$HOME/.colima/${PROFILE}/docker.sock}"

bash "$ROOT/ops/qai_colima_start_and_harden.sh"
bash "$ROOT/ops/qai_prod_preflight.sh"

docker compose -f "$ROOT/compose.master.yml" ps --format json > "$BACKUP_DIR/master.ps.before.json" || true
docker compose -f "$ROOT/compose.yml" -f "$ROOT/compose.override.yml" ps --format json > "$BACKUP_DIR/main.ps.before.json" || true
docker compose -f "$ROOT/docker-compose.base.yml" -f "$ROOT/docker-compose.override.yml" ps --format json > "$BACKUP_DIR/base.ps.before.json" || true

bash "$ROOT/ops/qai_stack_ops.sh" up all

sleep 12

bash "$ROOT/ops/qai_stack_ops.sh" ps all | tee "$BACKUP_DIR/ps.after.txt"
bash "$ROOT/ops/qai_health_summary.sh" | tee "$BACKUP_DIR/health.after.json"

printf 'CUTOVER_BACKUP_DIR=%s\n' "$BACKUP_DIR"
