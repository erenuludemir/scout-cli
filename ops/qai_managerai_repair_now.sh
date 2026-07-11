#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
cd "$ROOT"

export COLIMA_PROFILE="${COLIMA_PROFILE:-mcai-colima}"
export DOCKER_HOST="${DOCKER_HOST:-unix://$HOME/.colima/${COLIMA_PROFILE}/docker.sock}"

mkdir -p "$ROOT/_reports/managerai" "$ROOT/_logs/managerai"

echo "=== PRECHECK ==="
bash "$ROOT/ops/qai_manager_ai.sh" diagnose --json > "$ROOT/_reports/managerai/pre_repair_$(date +%Y%m%d_%H%M%S).json" || true

echo "=== RESTART metrics ==="
docker restart quantumai-stack-metrics-1 || true

echo "=== RESTART quantumai-usdt-v2 ==="
docker restart quantumai-usdt-v2 || true

echo "=== RESTART managerai-guard ==="
docker restart managerai-guard || true

echo "=== REBUILD targeted services ==="
bash "$ROOT/ops/qai_managerai_stack.sh" up -d --build managerai metrics quantumai-usdt-v2 managerai-broker managerai-guard || true

echo "=== WAIT ==="
sleep 20

echo "=== POSTCHECK ==="
bash "$ROOT/ops/qai_manager_ai.sh" diagnose --json > "$ROOT/_reports/managerai/post_repair_$(date +%Y%m%d_%H%M%S).json" || true

echo "=== METRICS HEALTH ==="
docker inspect --format '{{json .State.Health}}' quantumai-stack-metrics-1 2>/dev/null || true

echo "=== USDTV2 HEALTH ==="
docker inspect --format '{{json .State.Health}}' quantumai-usdt-v2 2>/dev/null || true

echo "=== MANAGERAI GUARD HEALTH ==="
docker inspect --format '{{json .State.Health}}' managerai-guard 2>/dev/null || true

echo "=== DONE ==="
