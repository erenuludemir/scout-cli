#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
source ./activate.sh

# 8000 doluysa 8001'e kay
PORT=${UVICORN_PORT:-8000}
lsof -tiTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1 && PORT=8001

# arka plandaki eski uvicorn'ları sustur
pkill -f "uvicorn .*:app" >/dev/null 2>&1 || true

echo "➡️  Uygulama: app/main.py | Port: $PORT"
exec uvicorn app.main:app --host 0.0.0.0 --port "$PORT" --reload
