#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="$ROOT/_logs/cadvisor_fix/$TS"
BAK_DIR="$ROOT/_backups/cadvisor_fix/$TS"
COMPOSE_FILE="$ROOT/compose.yml"

mkdir -p "$LOG_DIR" "$BAK_DIR"
cd "$ROOT"
cp -p "$COMPOSE_FILE" "$BAK_DIR/compose.yml.bak"

{
  echo "PWD=$PWD"
  echo "SHELL=$SHELL"
  echo "USER=$USER"
  echo "HOME=$HOME"
  echo "DOCKER_HOST=${DOCKER_HOST:-}"
  echo "PATH=$PATH"
} > "$LOG_DIR/env.txt"

command -v docker > "$LOG_DIR/which_docker.txt" 2>&1 || true
command -v colima > "$LOG_DIR/which_colima.txt" 2>&1 || true
docker context ls > "$LOG_DIR/docker_context_ls.txt" 2>&1 || true
docker context show > "$LOG_DIR/docker_context_show.txt" 2>&1 || true
CTX="$(docker context show 2>/dev/null || true)"
[ -n "$CTX" ] && docker context inspect "$CTX" > "$LOG_DIR/docker_context_inspect_current.json" 2>/dev/null || true
docker context inspect colima > "$LOG_DIR/docker_context_inspect_colima.json" 2>/dev/null || true
colima status > "$LOG_DIR/colima_status.txt" 2>&1 || true
colima list > "$LOG_DIR/colima_list.txt" 2>&1 || true

COLIMA_SOCK=""

if [ -n "${DOCKER_HOST:-}" ] && printf '%s' "${DOCKER_HOST:-}" | grep -q '^unix://'; then
  CANDIDATE="${DOCKER_HOST#unix://}"
  [ -S "$CANDIDATE" ] && COLIMA_SOCK="$CANDIDATE"
fi

if [ -z "$COLIMA_SOCK" ] && [ -f "$LOG_DIR/docker_context_inspect_current.json" ]; then
  COLIMA_SOCK="$(python3 - "$LOG_DIR/docker_context_inspect_current.json" <<'PY'
import json,sys
p=sys.argv[1]
try:
    data=json.load(open(p,"r",encoding="utf-8"))
    host=data[0]["Endpoints"]["docker"]["Host"]
    if isinstance(host,str) and host.startswith("unix://"):
        print(host[7:])
except Exception:
    pass
PY
)"
fi

if [ -z "$COLIMA_SOCK" ] && [ -f "$LOG_DIR/docker_context_inspect_colima.json" ]; then
  COLIMA_SOCK="$(python3 - "$LOG_DIR/docker_context_inspect_colima.json" <<'PY'
import json,sys
p=sys.argv[1]
try:
    data=json.load(open(p,"r",encoding="utf-8"))
    host=data[0]["Endpoints"]["docker"]["Host"]
    if isinstance(host,str) and host.startswith("unix://"):
        print(host[7:])
except Exception:
    pass
PY
)"
fi

for CANDIDATE in \
  "$HOME/.colima/default/docker.sock" \
  "$HOME/.colima/docker.sock" \
  "$HOME/.docker/run/docker.sock" \
  "/var/run/docker.sock"
do
  if [ -z "$COLIMA_SOCK" ] && [ -S "$CANDIDATE" ]; then
    COLIMA_SOCK="$CANDIDATE"
  fi
done

if [ -z "$COLIMA_SOCK" ]; then
  echo "COLIMA_SOCKET_BULUNAMADI" | tee "$LOG_DIR/error.txt"
  echo "DENE:" | tee -a "$LOG_DIR/error.txt"
  echo "1) docker context show" | tee -a "$LOG_DIR/error.txt"
  echo "2) docker context inspect colima" | tee -a "$LOG_DIR/error.txt"
  echo "3) ls -la ~/.colima ~/.colima/default ~/.docker/run /var/run/docker.sock" | tee -a "$LOG_DIR/error.txt"
  exit 1
fi

if [ ! -S "$COLIMA_SOCK" ]; then
  echo "COLIMA_SOCKET_GECERSIZ:$COLIMA_SOCK" | tee "$LOG_DIR/error.txt"
  exit 1
fi

printf '%s\n' "$COLIMA_SOCK" | tee "$LOG_DIR/colima_socket.txt"

python3 - "$COMPOSE_FILE" "$COLIMA_SOCK" <<'PY'
import pathlib, re, sys

compose_path = pathlib.Path(sys.argv[1])
sock = sys.argv[2]
text = compose_path.read_text(encoding="utf-8")

block = f"""  demo-app-cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.49.1
    container_name: quantumai-stack-demo-app-cadvisor-1
    command:
      - --housekeeping_interval=30s
      - --docker_only=true
      - --store_container_labels=false
      - --whitelisted_container_labels=com.docker.compose.project,com.docker.compose.service,com.docker.compose.container-number
    ports:
      - "18080:8080"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
      - {sock}:/var/run/docker.sock
    privileged: true
    restart: unless-stopped
"""

lines = text.splitlines(True)
start = None
end = None

for i, line in enumerate(lines):
    if re.match(r'^  demo-app-cadvisor:\s*$', line):
        start = i
        break

if start is None:
    sys.exit("demo-app-cadvisor_SERVISI_BULUNAMADI")

for j in range(start + 1, len(lines)):
    if re.match(r'^  [A-Za-z0-9_.-]+:\s*$', lines[j]):
        end = j
        break

if end is None:
    end = len(lines)

new_text = ''.join(lines[:start]) + block + ''.join(lines[end:])
compose_path.write_text(new_text, encoding="utf-8")
PY

docker compose --file "$COMPOSE_FILE" --project-name quantumai-stack config > "$LOG_DIR/compose.config.rendered.yml" 2> "$LOG_DIR/compose.config.err.log"
docker compose --file "$COMPOSE_FILE" --project-name quantumai-stack up -d --force-recreate demo-app-cadvisor > "$LOG_DIR/recreate.out.log" 2> "$LOG_DIR/recreate.err.log"

sleep 8

docker ps -a --filter "name=quantumai-stack-demo-app-cadvisor-1" > "$LOG_DIR/docker_ps.txt" 2>&1
docker inspect quantumai-stack-demo-app-cadvisor-1 > "$LOG_DIR/cadvisor.inspect.json" 2>&1 || true
docker logs --tail 300 quantumai-stack-demo-app-cadvisor-1 > "$LOG_DIR/cadvisor.logs.txt" 2>&1 || true
curl -fsS http://127.0.0.1:18080/metrics > "$LOG_DIR/cadvisor.metrics.txt" 2> "$LOG_DIR/cadvisor.metrics.err" || true
curl -fsS http://127.0.0.1:18080/healthz > "$LOG_DIR/cadvisor.healthz.txt" 2> "$LOG_DIR/cadvisor.healthz.err" || true

echo "LOG_DIR=$LOG_DIR"
echo "BAK_DIR=$BAK_DIR"
echo "SOCKET=$COLIMA_SOCK"
