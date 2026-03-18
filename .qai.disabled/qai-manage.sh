#!/usr/bin/env bash
set -euo pipefail
APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"
COMPOSE_FILE="${COMPOSE_FILE:-$APP_DIR/compose.master.yml}"
HOST_PORT="${HOST_PORT:-5003}"
log(){ printf "[%s] %s\n" "$(date +%F" "%T)" "$*"; }
tries=60
while ! docker info >/dev/null 2>&1; do ((tries--)) || { log "Docker gelmedi, çıkıyorum"; exit 0; }; sleep 1; done
OSVER="$(sw_vers -productVersion 2>/dev/null || echo unknown)"
OSBUILD="$(sw_vers -buildVersion 2>/dev/null || echo unknown)"
if [[ "$OSVER" == 15.4* ]] && [[ "$OSBUILD" =~ (beta|Beta|A|B) ]]; then log "Uyarı: macOS 15.4 beta üzerinde hypervisor sorunları görülebilir."; fi
if [[ ! -f "$COMPOSE_FILE" ]]; then log "compose dosyası yok: $COMPOSE_FILE"; exit 0; fi
docker compose -f "$COMPOSE_FILE" pull gli-mainnet || true
docker compose -f "$COMPOSE_FILE" up -d gli-mainnet || true
sleep 2
docker compose -f "$COMPOSE_FILE" up -d gli gli-sepolia || true
sleep 2
docker compose -f "$COMPOSE_FILE" up -d quantumai-usdt autoheal watchtower || true
curl -sf "http://127.0.0.1:${HOST_PORT}/" || curl -sf "http://127.0.0.1:5002/" || log "API henüz yanıt vermedi (başlangıç gecikmesi normal olabilir)"
