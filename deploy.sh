#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${APP_ROOT:-${SCRIPT_DIR}}"
ENV_FILE="$ROOT/.env"

cat >/etc/supervisor/supervisord.conf <<'EOF'
[supervisord]
nodaemon=true
logfile=/dev/null
logfile_maxbytes=0
loglevel=info
pidfile=/tmp/supervisord.pid
childlogdir=/var/log/supervisor

[program:gunicorn]
command=/usr/local/bin/gunicorn -w 4 -b 0.0.0.0:8080 app:app
directory=/app
autostart=true
autorestart=true
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0
user=root
priority=20
stopasgroup=true
killasgroup=true

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/dev/fd/1
stdout_logfile_maxbytes=0
stderr_logfile=/dev/fd/2
stderr_logfile_maxbytes=0
user=root
priority=10
stopasgroup=true
killasgroup=true
EOF

[ -f "$ENV_FILE" ] || touch "$ENV_FILE"

sed -i.bak 's/^\s*FLASK_ENV\s*=.*/# &/' "$ENV_FILE" || true
grep -qE '^\s*FLASK_DEBUG=' "$ENV_FILE" || echo 'FLASK_DEBUG=0' >> "$ENV_FILE"

# SECURITY: Do not auto-inject a default PRIVATE_KEY; require user to supply securely.
grep -qE '^\s*PRIVATE_KEY=' "$ENV_FILE" || echo '# PRIVATE_KEY=<set securely>' >> "$ENV_FILE"
grep -qE '^\s*NODE_URL=' "$ENV_FILE"    || echo 'NODE_URL=https://mainnet.infura.io/v3/a1308e9977764245b8d7b532a59ac7ee' >> "$ENV_FILE"
grep -qE '^\s*DATABASE_URL=' "$ENV_FILE"|| echo 'DATABASE_URL=postgresql://qaiuser:qaipass@localhost:5432/qai' >> "$ENV_FILE"

cd "$ROOT"

docker build -t quantumai-usdt-v2 .

docker ps --filter "publish=8080" -q | xargs -r docker stop

(lsof -ti tcp:8080 | xargs -r kill -9) || true

HOST_PORT="$(grep -E '^HOST_PORT=' "$ENV_FILE" | cut -d= -f2 || true)"
HOST_PORT="${HOST_PORT:-8080}"

docker run --rm \
  -p "${HOST_PORT}:8080" \
  -v "$ROOT:/app" \
  --env-file "$ENV_FILE" \
  quantumai-usdt-v2