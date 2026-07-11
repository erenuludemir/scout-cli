#!/usr/bin/env bash
set -euo pipefail
REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
cd "$REPO"
export DOCKER_CONTEXT="${DOCKER_CONTEXT:-colima-qai}"
export GRAFANA_HOST_PORT="${GRAFANA_HOST_PORT:-13000}"
export PROMETHEUS_HOST_PORT="${PROMETHEUS_HOST_PORT:-19090}"
export CADVISOR_HOST_PORT="${CADVISOR_HOST_PORT:-18080}"
docker context use "$DOCKER_CONTEXT" >/dev/null 2>&1 || true
BASE=""
for f in compose.yml docker-compose.yml; do
  [ -f "$REPO/$f" ] && BASE="$REPO/$f" && break
done
[ -n "$BASE" ] || { echo "BASE_COMPOSE_YOK"; exit 1; }
docker ps --format '{{.ID}} {{.Names}} {{.Ports}}' | awk '/:3000->|:9090->|:13000->|:19090->|:18080->/ {print $1}' | xargs -r docker stop >/dev/null 2>&1 || true
docker rm -f quantumai-cadvisor quantumai-autoheal >/dev/null 2>&1 || true
docker compose -f "$BASE" -f "$REPO/compose.resilience.override.yml" -p quantumai-stack up -d --remove-orphans
sleep 15
docker compose -f "$BASE" -f "$REPO/compose.resilience.override.yml" -p quantumai-stack ps
echo "GRAFANA=http://127.0.0.1:${GRAFANA_HOST_PORT}"
echo "PROMETHEUS=http://127.0.0.1:${PROMETHEUS_HOST_PORT}"
echo "OPS_KAPALI=varsayilan"
echo "OPS_AC=COMPOSE_PROFILES=ops docker compose -f \"$BASE\" -f \"$REPO/compose.resilience.override.yml\" -p quantumai-stack up -d cadvisor autoheal"
