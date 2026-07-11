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

docker context use colima-qai > "$LOG_DIR/docker_context_use.txt" 2>&1 || true
docker compose --file "$COMPOSE_FILE" --project-name quantumai-stack config > "$LOG_DIR/compose.rendered.yml" 2> "$LOG_DIR/compose.rendered.err.log"
docker compose --file "$COMPOSE_FILE" --project-name quantumai-stack up -d --force-recreate demo-app-cadvisor > "$LOG_DIR/up.out.log" 2> "$LOG_DIR/up.err.log"

sleep 15

docker ps -a --filter "name=quantumai-stack-demo-app-cadvisor-1" > "$LOG_DIR/docker_ps.txt" 2>&1
docker inspect quantumai-stack-demo-app-cadvisor-1 > "$LOG_DIR/cadvisor.inspect.json" 2>&1 || true
docker logs --tail 400 quantumai-stack-demo-app-cadvisor-1 > "$LOG_DIR/cadvisor.logs.txt" 2>&1 || true
curl -fsS http://127.0.0.1:18080/healthz > "$LOG_DIR/cadvisor.healthz.txt" 2> "$LOG_DIR/cadvisor.healthz.err" || true
curl -fsS http://127.0.0.1:18080/metrics > "$LOG_DIR/cadvisor.metrics.txt" 2> "$LOG_DIR/cadvisor.metrics.err" || true
curl -fsS http://127.0.0.1:9090/api/v1/targets > "$LOG_DIR/prometheus.targets.json" 2> "$LOG_DIR/prometheus.targets.err" || true

python3 - "$LOG_DIR" <<'PY'
import json, pathlib, re, sys
log_dir = pathlib.Path(sys.argv[1])
health = (log_dir / "cadvisor.healthz.txt").read_text(encoding="utf-8", errors="ignore").strip() if (log_dir / "cadvisor.healthz.txt").exists() else ""
metrics = (log_dir / "cadvisor.metrics.txt").read_text(encoding="utf-8", errors="ignore") if (log_dir / "cadvisor.metrics.txt").exists() else ""
logs = (log_dir / "cadvisor.logs.txt").read_text(encoding="utf-8", errors="ignore") if (log_dir / "cadvisor.logs.txt").exists() else ""
summary = {
  "healthz_ok": health == "ok",
  "metrics_present": "# HELP cadvisor_version_info" in metrics and "container_cpu_usage_seconds_total" in metrics,
  "docker_factory_registered": "Registration of the docker container factory successfully" in logs,
  "rw_layer_warnings_present": "failed to identify the read-write layer ID" in logs,
  "status": "OK" if health == "ok" and "# HELP cadvisor_version_info" in metrics else "FAIL"
}
(log_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8")
(log_dir / "summary.txt").write_text(
    "\n".join([
        f"STATUS={summary['status']}",
        f"HEALTHZ_OK={summary['healthz_ok']}",
        f"METRICS_PRESENT={summary['metrics_present']}",
        f"DOCKER_FACTORY_REGISTERED={summary['docker_factory_registered']}",
        f"RW_LAYER_WARNINGS_PRESENT={summary['rw_layer_warnings_present']}",
        "NOT=healthz_ok+metrics_present true ise servis calisiyor; rw_layer warning Colima/overlayfs katmaninda bilgilendirici olabilir."
    ]) + "\n",
    encoding="utf-8"
)
PY

echo "LOG_DIR=$LOG_DIR"
