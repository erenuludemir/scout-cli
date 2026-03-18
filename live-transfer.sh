set -euo pipefail
APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"
USDT_DIR="$APP_DIR/quantumai-usdt"
DEPLOY_DIR="$APP_DIR/.deploy"
HOST_PORT="${HOST_PORT:-8080}"
SERVICE_NAME="quantumai-usdt"
IMAGE_NAME="deploy-quantumai-usdt"
RECIPIENT="${RECIPIENT:-0xc5C600c86E13e8c475BCEbC981966d47E171A18c}"
AMOUNT="${AMOUNT:-1000000}"
mkdir -p "$DEPLOY_DIR"
test -d "$USDT_DIR" || exit 2
test -f "$USDT_DIR/.env" || exit 3
grep -Eq '^RPC_URL=https?://' "$USDT_DIR/.env" || exit 4
grep -Eq '^WALLET_ADDRESS=0x' "$USDT_DIR/.env" || exit 5
grep -Eq '^(PRIVATE_KEY|ETH_PRIVATE_KEY|TX_SENDER_PRIVATE_KEY)=0x' "$USDT_DIR/.env" || exit 6
if command -v colima >/dev/null 2>&1; then colima status 2>/dev/null | grep -q Running || colima start --cpu 4 --memory 6 --disk 60 >/dev/null 2>&1 || true; fi
if grep -q '^GLI_DRY_RUN=' "$USDT_DIR/.env"; then sed -i '' -E 's/^GLI_DRY_RUN=.*/GLI_DRY_RUN=0/' "$USDT_DIR/.env"; else printf '\nGLI_DRY_RUN=0\n' >> "$USDT_DIR/.env"; fi
cat > "$DEPLOY_DIR/wsgi.py" <<'PY'
import os,sys,importlib,importlib.util,types,glob
def _load_from_module(modname):
    try:
        m=importlib.import_module(modname)
    except Exception:
        return None
    for cand in ("app","application","api"):
        if hasattr(m,cand): return getattr(m,cand)
    if hasattr(m,"create_app") and callable(getattr(m,"create_app")): return m.create_app()
    return None
def _load_from_path(path):
    if not os.path.isfile(path): return None
    spec=importlib.util.spec_from_file_location("dynapp",path)
    if not spec or not spec.loader: return None
    m=importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(m)
    except Exception:
        return None
    for cand in ("app","application","api"):
        if hasattr(m,cand): return getattr(m,cand)
    if hasattr(m,"create_app") and callable(getattr(m,"create_app")): return m.create_app()
    return None
def resolve_app():
    entry=os.getenv("APP_ENTRY","").strip()
    if entry:
        if ":" in entry:
            left,right=entry.split(":",1)
            try:
                m=importlib.import_module(left)
                return getattr(m,right)
            except Exception:
                p=left if left.endswith(".py") else left+".py"
                cand=_load_from_path(p)
                if cand is not None: return cand
        else:
            cand=_load_from_module(entry)
            if cand is not None: return cand
    for mod in ("app","main","api","server"):
        cand=_load_from_module(mod)
        if cand is not None: return cand
    roots=["/app","/app/quantumai-usdt","/app/quantumai_usdt"]
    names=("wsgi.py","app.py","main.py","api.py","server.py")
    for r in roots:
        for n in names:
            cand=_load_from_path(os.path.join(r,n))
            if cand is not None: return cand
    for r in roots:
        for path in glob.glob(os.path.join(r,"**","*.py"),recursive=True):
            cand=_load_from_path(path)
            if cand is not None: return cand
    raise ImportError("Uygulama bulunamadı. APP_ENTRY ile belirtin ya da app/main/api.py içinde app|application|api veya create_app tanımlayın.")
app=resolve_app()
PY
cat > "$DEPLOY_DIR/Dockerfile" <<'DOCKER'
FROM python:3.11-slim
RUN apt-get update && apt-get install -y --no-install-recommends nginx supervisor curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN python -m pip install -U pip && pip install --no-cache-dir -r /app/requirements.txt
COPY . /app
COPY .deploy/wsgi.py /app/wsgi.py
RUN mkdir -p /run/nginx /var/log/supervisor
COPY .deploy/nginx.conf /etc/nginx/nginx.conf
COPY .deploy/supervisord.conf /etc/supervisor/supervisord.conf
EXPOSE 8080
CMD ["/usr/bin/supervisord","-c","/etc/supervisor/supervisord.conf"]
DOCKER
cat > "$DEPLOY_DIR/nginx.conf" <<'NGINX'
worker_processes auto;
events { worker_connections 1024; }
http {
  sendfile on;
  server {
    listen 8080 default_server;
    server_name _;
    location /health { proxy_pass http://127.0.0.1:5002/health; proxy_set_header Host $host; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; }
    location / { proxy_http_version 1.1; proxy_set_header Connection ""; proxy_set_header Host $host; proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; proxy_set_header X-Forwarded-Proto $scheme; proxy_pass http://127.0.0.1:5002; }
  }
}
NGINX
cat > "$DEPLOY_DIR/supervisord.conf" <<'SUP'
[unix_http_server]
file=/var/run/supervisor.sock
chmod=0700
[rpcinterface:supervisor]
factory=supervisor.rpcinterface:make_main_rpcinterface
[supervisord]
nodaemon=true
logfile=/var/log/supervisord.log
pidfile=/var/run/supervisord.pid
childlogdir=/var/log/supervisor
[supervisorctl]
serverurl=unix:///var/run/supervisor.sock
[program:gunicorn]
directory=/app
command=/usr/local/bin/gunicorn -b 127.0.0.1:5002 wsgi:app --workers 2 --threads 4 --timeout 120
autostart=true
autorestart=true
stopsignal=TERM
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
[program:nginx]
command=/usr/sbin/nginx -g 'daemon off;'
autostart=true
autorestart=true
stopsignal=QUIT
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
SUP
cat > "$DEPLOY_DIR/docker-compose.yml" <<COMPOSE
services:
  quantumai-usdt:
    build:
      context: ..
      dockerfile: .deploy/Dockerfile
    container_name: quantumai-usdt
    image: $IMAGE_NAME:latest
    ports:
      - "${HOST_PORT:-8080}:8080"
    env_file:
      - ../quantumai-usdt/.env
    environment:
      - APP_ENTRY=${APP_ENTRY-}
    healthcheck:
      test: ["CMD-SHELL","curl -fsS http://127.0.0.1:8080/health || exit 1"]
      interval: 3s
      timeout: 2s
      retries: 60
      start_period: 5s
    restart: unless-stopped
COMPOSE
docker compose -f "$DEPLOY_DIR/docker-compose.yml" down -v --remove-orphans >/dev/null 2>&1 || true
docker ps -a --filter "name=$SERVICE_NAME" --format '{{.ID}}' | xargs -r docker rm -f >/dev/null 2>&1 || true
docker rm -f "$SERVICE_NAME" >/dev/null 2>&1 || true
docker compose -f "$DEPLOY_DIR/docker-compose.yml" build
docker compose -f "$DEPLOY_DIR/docker-compose.yml" up -d --force-recreate
tries=180
until curl -fsS "http://127.0.0.1:${HOST_PORT}/health" | python3 - <<'PY'
import sys,json
try:
  d=json.load(sys.stdin)
  sys.exit(0 if (d.get("ok") and d.get("ready")) else 1)
except Exception:
  sys.exit(1)
PY
do
  tries=$((tries-1))
  if [ $tries -le 0 ]; then
    docker logs --tail=200 "$SERVICE_NAME" || true
    docker exec "$SERVICE_NAME" sh -lc 'supervisorctl status || true' || true
    docker exec "$SERVICE_NAME" sh -lc 'ss -ltnp || netstat -lntp || true' || true
    exit 10
  fi
  sleep 1
done
curl -fsS "http://127.0.0.1:${HOST_PORT}/health" | python3 -m json.tool || true
send_once() { curl -fsS -X POST "http://127.0.0.1:${HOST_PORT}/transfer" -H 'Content-Type: application/json' -d "{\"recipient\":\"$RECIPIENT\",\"amount\":$AMOUNT}"; }
RESP="$(send_once || true)"
[ -z "$RESP" ] && RESP="{}"
printf '%s' "$RESP" | python3 -m json.tool || true
STATUS="$(python3 - <<'PY'
import json,sys
d=json.loads(sys.stdin.read())
print(d.get("status",""))
PY
<<<"$RESP"
)"
TXHASH="$(python3 - <<'PY'
import json,sys
d=json.loads(sys.stdin.read())
print(d.get("tx_hash") or d.get("tx_hash_computed") or "")
PY
<<<"$RESP"
)"
if [ "$STATUS" = "preview" ]; then
  sed -i '' -E 's/^GLI_DRY_RUN=.*/GLI_DRY_RUN=0/' "$USDT_DIR/.env"
  docker compose -f "$DEPLOY_DIR/docker-compose.yml" up -d --build --force-recreate
  for _ in $(seq 1 60); do curl -fsS "http://127.0.0.1:${HOST_PORT}/health" >/dev/null 2>&1 && break; sleep 2; done
  RESP="$(send_once || true)"
  [ -z "$RESP" ] || printf '%s' "$RESP" | python3 -m json.tool || true
  TXHASH="$(python3 - <<'PY'
import json,sys
d=json.loads(sys.stdin.read())
print(d.get("tx_hash") or d.get("tx_hash_computed") or "")
PY
<<<"$RESP"
)"
fi
[ -z "$TXHASH" ] && exit 12
RPC_URL="$(grep -E '^RPC_URL=' "$USDT_DIR/.env" | sed 's/^RPC_URL=//')"
[ -n "$RPC_URL" ] || exit 13
for _ in $(seq 1 90); do
  RCPT="$(curl -fsS -H 'Content-Type: application/json' -X POST "$RPC_URL" -d "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getTransactionReceipt\",\"params\":[\"$TXHASH\"],\"id\":1}")"
  GOT="$(python3 - <<'PY'
import json,sys
try:
  d=json.loads(sys.stdin.read())
  print("ok" if d.get("result") else "wait")
except Exception:
  print("wait")
PY
<<<"$RCPT"
)"
  if [ "$GOT" = "ok" ]; then echo "$RCPT" | python3 -m json.tool; echo "https://etherscan.io/tx/$TXHASH"; break; fi
  sleep 2
done