#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "[QAI] Ensuring Colima (Docker) is up…"
colima start || true
echo "[QAI] Building image if missing…"
docker image inspect quantumai-usdt.apps:latest >/dev/null 2>&1 || docker build -t quantumai-usdt.apps .
echo "[QAI] Starting compose…"
docker compose up -d
echo "[QAI] Tailing logs (Ctrl+C to detach)…"
docker compose logs -f --tail=200
