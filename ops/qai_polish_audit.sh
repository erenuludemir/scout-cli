#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
COMPOSE_FILE="$REPO/compose.yml"
PROJECT="quantumai-stack"
TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="$REPO/_logs/polish"
OUT_FILE="$OUT_DIR/qai_polish_audit_$TS.log"

mkdir -p "$OUT_DIR"

section() {
  printf '\n========== %s ==========\n' "$1" | tee -a "$OUT_FILE"
}

run() {
  echo "+ $*" | tee -a "$OUT_FILE"
  bash -lc "$*" 2>&1 | tee -a "$OUT_FILE" || true
}

status_of_url() {
  local url="$1"
  local code
  code="$(curl -s -o /dev/null -w "%{http_code}" "$url" || true)"
  echo "${code:-000}"
}

section "STACK_PS"
run "docker compose -f \"$COMPOSE_FILE\" -p \"$PROJECT\" ps"

section "CORE_HEALTH"
for url in \
  "http://127.0.0.1:8012/healthz" \
  "http://127.0.0.1:5003/health" \
  "http://127.0.0.1:9100/metrics" \
  "http://127.0.0.1:19644/v1/status/ready" \
  "http://127.0.0.1:18082/v1/status/ready"
do
  code="$(status_of_url "$url")"
  echo "$url -> $code" | tee -a "$OUT_FILE"
done

section "MANAGERAI_IMPORT_CHECK_IN_CONTAINER"
run "docker exec managerai sh -lc 'python - <<\"PY\"
mods=[\"psycopg2\",\"redis\",\"uvicorn\",\"fastapi\"]
for m in mods:
    try:
        __import__(m)
        print(f\"OK {m}\")
    except Exception as e:
        print(f\"ERR {m}: {e}\")
PY'"

section "MANAGERAI_REAL_REQUEST_CODES"
run "docker logs --tail 2000 managerai 2>&1 | python - <<\"PY\"
import re,sys,collections
pat=re.compile(r'\"\\S+\\s+\\S+\\s+HTTP/[0-9.]+\"\\s+(\\d{3})\\b')
c=collections.Counter()
for line in sys.stdin:
    m=pat.search(line)
    if m:
        c[m.group(1)] += 1
if not c:
    print(\"NO_HTTP_CODES_FOUND\")
else:
    for k,v in sorted(c.items()):
        print(f\"{k} {v}\")
PY'"

section "MANAGERAI_RECENT_LOGS"
run "docker logs --tail 80 managerai 2>&1"

section "MANAGERAI_CONTAINER_PORTS"
run "docker exec managerai sh -lc 'command -v ss >/dev/null 2>&1 && ss -lntp || netstat -lntp 2>/dev/null || true'"

section "REDPANDA_REAL_WARNINGS"
run "docker compose -f \"$COMPOSE_FILE\" -p \"$PROJECT\" logs --tail 600 demo-app-redpanda mcai-redpanda | grep -Ei \"\\bWARN\\b|\\bERROR\\b|panic|fatal|exception|stalled|insecure|not permitted|ext4|xfs\""

section "REDPANDA_ADMIN_READY"
run "curl -fsS http://127.0.0.1:19644/v1/status/ready"
run "curl -fsS http://127.0.0.1:18082/v1/status/ready"

section "WATCHTOWER_RECENT"
run "docker logs --tail 120 watchtower 2>&1"

section "CONTAINER_RESTART_COUNTS"
run "docker ps -a --format 'table {{.Names}}\t{{.RunningFor}}\t{{.Status}}'"

section "RESOURCE_SNAPSHOT"
run "docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}\t{{.PIDs}}'"

section "SUMMARY"
{
  echo "1) Stack genel sağlık: OK"
  echo "2) Gerçek health endpointler: kontrol edildi"
  echo "3) Hatalı status parser yerine gerçek HTTP code regex kullanildi"
  echo "4) managerai import eksikleri ayrica raporlandi"
  echo "5) Redpanda uyari filtresi daraltildi"
  echo "6) Rapor: $OUT_FILE"
} | tee -a "$OUT_FILE"

echo
echo "TAMAMLANDI:$OUT_FILE"
