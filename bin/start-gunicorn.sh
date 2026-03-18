docker build --no-cache -t quantumai-usdt-v2 .#!/bin/bash
set -Eeuo pipefail
APP_DIR="$HOME/QuantumAI-Dockerized-System"
VENV="$APP_DIR/.venv-host"

export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
[ -f "$VENV/bin/activate" ] && source "$VENV/bin/activate"

if [[ -f "$APP_DIR/.env" ]]; then
  set -a
  /usr/bin/grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$APP_DIR/.env" | /usr/bin/sed 's/\r$//' > "$APP_DIR/.env.export"
  . "$APP_DIR/.env.export"
  set +a
fi

cd "$APP_DIR"
exec gunicorn -w 2 -k gthread --threads 4 --timeout 180 \
  --access-logfile "$APP_DIR/logs/gunicorn.access.log" \
  --error-logfile "$APP_DIR/logs/gunicorn.err.log" \
  -b 127.0.0.1:5003 app:app
