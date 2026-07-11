#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
COMPOSE_FILE="$REPO/compose.yml"
PROJECT_NAME="quantumai-stack"
TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="$REPO/_logs/tests/$TS"
mkdir -p "$OUT_DIR"

PASS=0
WARN=0
FAIL=0

pass(){ printf '[PASS] %s\n' "$1" | tee -a "$OUT_DIR/summary.log"; PASS=$((PASS+1)); }
warn(){ printf '[WARN] %s\n' "$1" | tee -a "$OUT_DIR/summary.log"; WARN=$((WARN+1)); }
fail(){ printf '[FAIL] %s\n' "$1" | tee -a "$OUT_DIR/summary.log"; FAIL=$((FAIL+1)); }

test_cmd(){
  local name="$1"; shift
  if "$@" >"$OUT_DIR/$(echo "$name" | tr ' /:' '___').out" 2>"$OUT_DIR/$(echo "$name" | tr ' /:' '___').err"; then
    pass "$name"
  else
    fail "$name"
  fi
}

test_http(){
  local name="$1" url="$2"
  if curl -fsS --max-time 8 "$url" >"$OUT_DIR/$(echo "$name" | tr ' /:' '___').out" 2>"$OUT_DIR/$(echo "$name" | tr ' /:' '___').err"; then
    pass "$name $url"
  else
    fail "$name $url"
  fi
}

test_http_soft(){
  local name="$1" url="$2"
  if curl -fsS --max-time 8 "$url" >"$OUT_DIR/$(echo "$name" | tr ' /:' '___').out" 2>"$OUT_DIR/$(echo "$name" | tr ' /:' '___').err"; then
    pass "$name $url"
  else
    warn "$name $url"
  fi
}

{
  echo "TS=$TS"
  echo "REPO=$REPO"
  echo "COMPOSE_FILE=$COMPOSE_FILE"
  echo "PWD=$(pwd)"
  echo "DATE=$(date)"
  echo "DOCKER_CONTEXT=$(docker context show 2>/dev/null || true)"
  echo "DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || true)"
  echo "COMPOSE_VERSION=$(docker compose version 2>/dev/null || true)"
} | tee "$OUT_DIR/meta.log"

[ -f "$COMPOSE_FILE" ] || { echo "COMPOSE_YOK:$COMPOSE_FILE" | tee -a "$OUT_DIR/summary.log"; exit 1; }

cd "$REPO"

test_cmd "docker info" docker info
test_cmd "compose config" docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" config
test_cmd "compose ps" docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps > "$OUT_DIR/compose_ps.txt" 2>&1 || true
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' > "$OUT_DIR/docker_ps.txt" 2>&1 || true

SERVICES=(
  "managerai|http://127.0.0.1:8012/healthz"
  "managerai-broker|http://127.0.0.1:8787/healthz"
  "gateway|http://127.0.0.1:5003/health"
  "metrics|http://127.0.0.1:9100/metrics"
  "redpanda-demo-ready|http://127.0.0.1:19644/v1/status/ready"
  "redpanda-mcai-ready|http://127.0.0.1:18082/v1/status/ready"
  "grafana-health|http://127.0.0.1:3000/api/health"
  "prometheus-ready|http://127.0.0.1:9090/-/ready"
  "mcai-api|http://127.0.0.1:18100/health"
  "mcai-feeder|http://127.0.0.1:18101/health"
  "mcai-router|http://127.0.0.1:18102/health"
  "mcai-sim|http://127.0.0.1:18103/health"
  "mcai-large-exec|http://127.0.0.1:18104/health"
  "mcai-risk|http://127.0.0.1:18105/health"
  "mcai-small-agg|http://127.0.0.1:18106/health"
  "mcai-trade-engine|http://127.0.0.1:18107/health"
  "demo-app-qai|http://127.0.0.1:18000/health"
  "cadvisor|http://127.0.0.1:18080/healthz"
  "gli-mainnet|http://127.0.0.1:5002/health"
  "gli-sepolia|http://127.0.0.1:5004/health"
  "gli-container|http://127.0.0.1:5006/health"
  "quantumai-usdt-v2|http://127.0.0.1:5005/health"
  "rosettaai|http://127.0.0.1:5090/health"
)

for item in "${SERVICES[@]}"; do
  name="${item%%|*}"
  url="${item#*|}"
  test_http_soft "$name" "$url"
done

if docker ps --format '{{.Names}}' | grep -qx 'managerai'; then
  if docker exec managerai sh -lc 'python - <<PY
mods=["psycopg2","redis","uvicorn","fastapi"]
bad=0
for m in mods:
    try:
        __import__(m)
        print("OK",m)
    except Exception as e:
        bad=1
        print("ERR",m,e)
raise SystemExit(bad)
PY' > "$OUT_DIR/managerai_python_deps.out" 2> "$OUT_DIR/managerai_python_deps.err"; then
    pass "managerai python deps"
  else
    warn "managerai python deps"
  fi
else
  fail "managerai container missing"
fi

docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" logs --tail=300 > "$OUT_DIR/compose_logs_tail300.log" 2>&1 || true

CRIT_PAT='Loading on-disk chunks failed|out of sequence m-mapped chunk|Unknown series references|Worker .* exited with code 1|Traceback|CancelledError|Insecure Admin API listener|Reactor stalled|perf_event_open\(\) failed|postgres_exporter.yml|failed to identify the read-write layer ID|mount-id: no such file or directory|panic|fatal|exception|segmentation fault'
grep -Eai "$CRIT_PAT" "$OUT_DIR/compose_logs_tail300.log" > "$OUT_DIR/critical_matches.log" || true

if grep -Eaq 'Loading on-disk chunks failed|out of sequence m-mapped chunk|Unknown series references' "$OUT_DIR/compose_logs_tail300.log"; then
  fail "prometheus tsdb corruption izleri bulundu"
else
  pass "prometheus tsdb corruption izi yok"
fi

if grep -Eaq 'Insecure Admin API listener' "$OUT_DIR/compose_logs_tail300.log"; then
  warn "redpanda admin api insecure"
else
  pass "redpanda admin api insecure log yok"
fi

if grep -Eaq 'postgres_exporter.yml' "$OUT_DIR/compose_logs_tail300.log"; then
  warn "postgres exporter config eksik izi bulundu"
else
  pass "postgres exporter config eksik izi yok"
fi

if grep -Eaq 'failed to identify the read-write layer ID|mount-id: no such file or directory' "$OUT_DIR/compose_logs_tail300.log"; then
  warn "cadvisor docker overlay layerdb uyuşmazlığı bulundu"
else
  pass "cadvisor overlay layerdb uyarısı yok"
fi

if grep -Eaq 'Worker .* exited with code 1' "$OUT_DIR/compose_logs_tail300.log"; then
  warn "gunicorn worker exit izi bulundu"
else
  pass "gunicorn worker exit izi yok"
fi

if grep -Eaq 'Reactor stalled' "$OUT_DIR/compose_logs_tail300.log"; then
  warn "redpanda reactor stall izi bulundu"
else
  pass "redpanda reactor stall izi yok"
fi

{
  echo "========== NET DURUM =========="
  echo "PASS=$PASS"
  echo "WARN=$WARN"
  echo "FAIL=$FAIL"
  echo
  echo "========== AYAKTA OLMAYAN/KRITIK =========="
  docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps --format json 2>/dev/null | python3 - <<'PY' || true
import sys, json
try:
    data=json.load(sys.stdin)
except Exception:
    data=[]
bad=[]
for x in data:
    st=(x.get("State") or "") + " " + (x.get("Health") or "")
    if "running" not in st.lower() and "healthy" not in st.lower():
        bad.append(x)
if not bad:
    print("YOK")
else:
    for x in bad:
        print(f'{x.get("Service","?")} | {x.get("State","?")} | {x.get("Health","")}')
PY
  echo
  echo "========== KRITIK LOG ESLESMELERI =========="
  if [ -s "$OUT_DIR/critical_matches.log" ]; then
    tail -n 200 "$OUT_DIR/critical_matches.log"
  else
    echo "YOK"
  fi
  echo
  echo "========== ONCELIKLI TESPIT =========="
  if grep -Eaq 'Loading on-disk chunks failed|out of sequence m-mapped chunk|Unknown series references' "$OUT_DIR/compose_logs_tail300.log"; then
    echo "1) PROMETHEUS_TSDB"
  fi
  if grep -Eaq 'failed to identify the read-write layer ID|mount-id: no such file or directory' "$OUT_DIR/compose_logs_tail300.log"; then
    echo "2) CADVISOR_DOCKER_LAYERDB"
  fi
  if grep -Eaq 'Insecure Admin API listener' "$OUT_DIR/compose_logs_tail300.log"; then
    echo "3) REDPANDA_ADMIN_API"
  fi
  if grep -Eaq 'postgres_exporter.yml' "$OUT_DIR/compose_logs_tail300.log"; then
    echo "4) POSTGRES_EXPORTER_CONFIG"
  fi
  if grep -Eaq 'Worker .* exited with code 1' "$OUT_DIR/compose_logs_tail300.log"; then
    echo "5) GLI_GUNICORN_BOOT"
  fi
  echo
  echo "REPORT_DIR=$OUT_DIR"
} | tee -a "$OUT_DIR/final_report.txt"

if [ "$FAIL" -gt 0 ]; then
  exit 2
fi
exit 0
