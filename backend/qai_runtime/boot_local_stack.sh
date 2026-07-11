#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$ROOT/compose.dev.yml"
DOCKER_SOCKET="${DOCKER_SOCKET:-unix:///Users/erenuludemir/.colima/default/docker.sock}"

docker_cmd() {
  env -u DOCKER_HOST -u DOCKER_CONTEXT docker --host "$DOCKER_SOCKET" "$@"
}

profile_status="$(colima list 2>/dev/null | awk '$1=="default" { print $2 }')"
if [ "${profile_status:-Stopped}" != "Running" ]; then
  colima start --profile default --runtime docker --cpu 4 --memory 8 --disk 100 >/dev/null
fi

for _ in {1..30}; do
  if docker_cmd info >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

if ! docker_cmd info >/dev/null 2>&1; then
  echo "Docker daemon did not become ready on $DOCKER_SOCKET" >&2
  exit 1
fi

pkill -f "uvicorn app.main:app --host 0.0.0.0 --port 8787" || true
pkill -f "python -m app.worker" || true

docker_cmd compose -f "$COMPOSE_FILE" up -d --build

echo "Waiting for qai-runtime-api to become healthy..."
for _ in {1..30}; do
  health_state="$(docker_cmd inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' qai-runtime-api 2>/dev/null || true)"
  if [ "$health_state" = "healthy" ]; then
    break
  fi
  sleep 2
done

docker_cmd compose -f "$COMPOSE_FILE" ps
curl -fsS http://127.0.0.1:8787/health
