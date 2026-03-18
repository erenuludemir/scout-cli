#!/bin/bash
set -euo pipefail
LOG_DIR="$HOME/QuantumAI-Dockerized-System/.qai"

cd "$LOG_DIR"
log() {
  echo "[$(date '+%F %T')] $*"
}

log "⏳ QAI Self-Agent başlatılıyor..."

python3 fuel_health.py >> agent.fuel.log 2>&1 &

python3 docker_watcher.py >> agent.docker.log 2>&1 &

python3 log_guard.py >> agent.logs.log 2>&1 &

python3 gpt_sync_monitor.py >> agent.gpt.log 2>&1 &

log "✅ QAI Self-Agent tüm modülleri başlattı."
