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

docker context use colima-qai > "$LOG_DIR/docker_context_use.txt" 2>&1 || true
docker context show > "$LOG_DIR/docker_context_show.txt" 2>&1 || true
docker context inspect colima-qai > "$LOG_DIR/docker_context_inspect_colima_qai.json" 2>&1 || true
docker ps > "$LOG_DIR/docker_ps_before.txt" 2>&1 || true

python3 - "$COMPOSE_FILE" <<'PY'
import pathlib, re, sys

compose_path = pathlib.Path(sys.argv[1])
text = compose_path.read_text(encoding="utf-8")

block = """  demo-app-cadvisor:
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
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
      - /var/run/docker.sock:/var/run/docker.sock:rw
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

docker compose --file "$COMPOSE_FILE" --project-name quantumai-stack config > "$LOG_DIR/compose.rendered.yml" 2> "$LOG_DIR/compose.rendered.err.log"
docker compose --file "$COMPOSE_FILE" --project-name quantumai-stack rm -sf demo-app-cadvisor > "$LOG_DIR/rm.out.log" 2> "$LOG_DIR/rm.err.log" || true
docker compose --file "$COMPOSE_FILE" --project-name quantumai-stack up -d --force-recreate demo-app-cadvisor > "$LOG_DIR/up.out.log" 2> "$LOG_DIR/up.err.log"

sleep 10

docker ps -a --filter "name=quantumai-stack-demo-app-cadvisor-1" > "$LOG_DIR/docker_ps_after.txt" 2>&1
docker inspect quantumai-stack-demo-app-cadvisor-1 > "$LOG_DIR/cadvisor.inspect.json" 2>&1 || true
docker logs --tail 300 quantumai-stack-demo-app-cadvisor-1 > "$LOG_DIR/cadvisor.logs.txt" 2>&1 || true
curl -sv http://127.0.0.1:18080/healthz > "$LOG_DIR/cadvisor.healthz.txt" 2> "$LOG_DIR/cadvisor.healthz.err" || true
curl -sv http://127.0.0.1:18080/metrics > "$LOG_DIR/cadvisor.metrics.txt" 2> "$LOG_DIR/cadvisor.metrics.err" || true

echo "LOG_DIR=$LOG_DIR"
echo "CONTEXT=$(docker context show 2>/dev/null || true)"
