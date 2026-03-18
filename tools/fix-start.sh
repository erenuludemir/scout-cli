#!/usr/bin/env bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:$PATH"

APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"
COMPOSE="${COMPOSE:-$APP_DIR/compose.yml}"
DOCKER_USERNAME="${DOCKER_USERNAME:-erenuludemir}"

echo "[i] Etkin Docker context: $(docker context show 2>/dev/null || echo default)"

if ! docker info >/dev/null 2>&1; then
  echo "[i] Docker daemon'a ulaşılamadı. Colima varsa uyandırmayı deniyorum..."
  colima start >/dev/null 2>&1 || true
  for i in $(seq 1 120); do
    docker info >/dev/null 2>&1 && break
    sleep 1
  done
fi

if [[ -n "${DOCKER_PAT:-}" ]]; then
  printf "%s" "$DOCKER_PAT" | docker login -u "$DOCKER_USERNAME" --password-stdin
fi

cd "$APP_DIR"
docker compose -f "$COMPOSE" pull || true
docker compose -f "$COMPOSE" up -d
docker compose -f "$COMPOSE" ps