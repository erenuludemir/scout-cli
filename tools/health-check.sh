#!/usr/bin/env bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:$PATH"

APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"
COMPOSE="${COMPOSE:-$APP_DIR/compose.yml}"

if ! docker info >/dev/null 2>&1; then
  echo "[i] Docker/Colima yeniden bağlanıyor…"
  colima start >/dev/null 2>&1 || true
fi

if ! docker compose -f "$COMPOSE" ps --status running | grep -q .; then
  echo "[i] Servisler ayağa kaldırılıyor…"
  docker compose -f "$COMPOSE" up -d
fi

if command -v curl >/dev/null 2>&1; then
  curl -sf "http://127.0.0.1:5003/" >/dev/null 2>&1 || true
fi
