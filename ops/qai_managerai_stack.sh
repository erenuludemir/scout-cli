#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${COLIMA_PROFILE:-mcai-colima}"

if ! docker info >/dev/null 2>&1 && command -v colima >/dev/null 2>&1; then
  colima start --profile "$PROFILE" >/dev/null 2>&1 || true
fi

export DOCKER_HOST="${DOCKER_HOST:-unix://$HOME/.colima/${PROFILE}/docker.sock}"
unset COMPOSE_FILE

COMPOSE_FILE="$ROOT/compose.managerai.yml"
ARGS=(-f "$COMPOSE_FILE")

if docker compose version >/dev/null 2>&1; then
  exec docker compose "${ARGS[@]}" "$@"
elif command -v docker-compose >/dev/null 2>&1; then
  exec docker-compose "${ARGS[@]}" "$@"
fi

echo "DOCKER_COMPOSE_YOK" >&2
exit 1
