#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${COLIMA_PROFILE:-mcai-colima}"

export DOCKER_HOST="${DOCKER_HOST:-unix://$HOME/.colima/${PROFILE}/docker.sock}"
unset COMPOSE_FILE

if [ -z "${SUPERVIZOR_COMPOSE_FILES:-}" ]; then
  export SUPERVIZOR_COMPOSE_FILES="compose.master.yml,compose.yml,compose.override.yml,docker-compose.base.yml,docker-compose.override.yml,compose.managerai.yml"
fi

if [ -z "${SUPERVIZOR_SERVICE_ALLOWLIST:-}" ]; then
  export SUPERVIZOR_SERVICE_ALLOWLIST="managerai,managerai-broker,managerai-guard,gateway,dex,quantumai-usdt,quantumai-usdt-v2,rosettaai,metrics,redis,gli,gli-mainnet,gli-sepolia,autoheal,watchtower"
fi

exec bash "$ROOT/orchestrator/SupervizorAI.sh" "$@"
