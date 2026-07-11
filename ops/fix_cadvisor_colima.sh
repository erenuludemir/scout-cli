#!/usr/bin/env bash
set -euo pipefail
ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="$ROOT/_logs/cadvisor_fix/$TS"
mkdir -p "$LOG_DIR"
cd "$ROOT"

DOCKER_HOST_VALUE="${DOCKER_HOST:-}"
COLIMA_SOCK=""
if [ -n "$DOCKER_HOST_VALUE" ] && printf '%s' "$DOCKER_HOST_VALUE" | grep -q '^unix://'; then
  CANDIDATE="${DOCKER_HOST_VALUE#unix://}"
  [ -S "$CANDIDATE" ] && COLIMA_SOCK="$CANDIDATE"
fi
[ -z "$COLIMA_SOCK" ] && [ -S "$HOME/.colima/default/docker.sock" ] && COLIMA_SOCK="$HOME/.colima/default/docker.sock"
[ -z "$COLIMA_SOCK" ] && [ -S "$HOME/.colima/docker.sock" ] && COLIMA_SOCK="$HOME/.colima/docker.sock"
[ -z "$COLIMA_SOCK" ] && command -v docker >/dev/null 2>&1 && docker context inspect colima > "$LOG_DIR/docker_context_colima.json" 2>/dev/null || true
if [ -z "$COLIMA_SOCK" ] && [ -f "$LOG_DIR/docker_context_colima.json" ]; then
  COLIMA_SOCK="$(python3 - <<'PY'
import json,sys
p=sys.argv[1]
try:
    data=json.load(open(p))
    ep=data[0]["Endpoints"]["docker"]["Host"]
    if ep.startswith("unix://"):
        print(ep[7:])
except Exception:
    pass
PY
"$LOG_DIR/docker_context_colima.json")"
fi
[ -n "${COLIMA_SOCK:-}" ] || { echo "COLIMA_SOCKET_BULUNAMADI" | tee "$LOG_DIR/error.txt"; exit 1; }
[ -S "$COLIMA_SOCK" ] || { echo "COLIMA_SOCKET_GECERSIZ:$COLIMA_SOCK" | tee "$LOG_DIR/error.txt"; exit 1; }

printf '%s\n' "$COLIMA_SOCK" | tee "$LOG_DIR/colima_socket.txt"

python3 - "$ROOT/compose.yml" "$COLIMA_SOCK" <<'PY'
import re, sys, pathlib
compose_path = pathlib.Path(sys.argv[1])
sock = sys.argv[2]
text = compose_path.read_text()
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
compose_path.write_text(new_text)
PY

docker compose --file "$ROOT/compose.yml" --project-name quantumai-stack config > "$LOG_DIR/compose.config.rendered.yml"
docker compose --file "$ROOT/compose.yml" --project-name quantumai-stack up -d --force-recreate demo-app-cadvisor > "$LOG_DIR/recreate.out.log" 2> "$LOG_DIR/recreate.err.log"
sleep 8
docker ps -a --filter "name=quantumai-stack-demo-app-cadvisor-1" > "$LOG_DIR/docker_ps.txt"
docker inspect quantumai-stack-demo-app-cadvisor-1 > "$LOG_DIR/cadvisor.inspect.json"
docker logs --tail 300 quantumai-stack-demo-app-cadvisor-1 > "$LOG_DIR/cadvisor.logs.txt" 2>&1 || true
curl -fsS http://127.0.0.1:18080/metrics > "$LOG_DIR/cadvisor.metrics.txt" 2> "$LOG_DIR/cadvisor.metrics.err" || true
curl -fsS http://127.0.0.1:18080/healthz > "$LOG_DIR/cadvisor.healthz.txt" 2> "$LOG_DIR/cadvisor.healthz.err" || true
echo "LOG_DIR=$LOG_DIR"
echo "SOCKET=$COLIMA_SOCK"
