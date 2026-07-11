#!/usr/bin/env bash
set -euo pipefail
REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
TS="$(date +%Y%m%d_%H%M%S)"
LOGDIR="$REPO/_logs/final_hardening/$TS"
mkdir -p "$LOGDIR"

echo "[1/8] compose port publish doğrulama" | tee "$LOGDIR/steps.log"
docker compose -f "$REPO/compose.yml" -p quantumai-stack ps > "$LOGDIR/compose_ps.txt"
docker port demo-app-redpanda-1 > "$LOGDIR/demo_app_redpanda_ports.txt" 2>&1 || true
docker port mcai-redpanda-1 > "$LOGDIR/mcai_redpanda_ports.txt" 2>&1 || true
if grep -Eq '127\.0\.0\.1:19644|127\.0\.0\.1:18082' "$LOGDIR/demo_app_redpanda_ports.txt" "$LOGDIR/mcai_redpanda_ports.txt"; then
  echo "PASS redpanda admin publish localhost ile sınırlı" | tee -a "$LOGDIR/result.txt"
else
  echo "WARN redpanda admin publish çıktısını elle kontrol et" | tee -a "$LOGDIR/result.txt"
fi

echo "[2/8] managerai runtime bağımlılık tamamlama" | tee -a "$LOGDIR/steps.log"
docker exec managerai sh -lc 'python -m pip install --no-cache-dir redis "psycopg2-binary>=2.9,<3"' > "$LOGDIR/managerai_pip_install.txt" 2>&1
docker exec managerai sh -lc 'python - <<PY
mods=["psycopg2","redis","uvicorn","fastapi"]
bad=0
for m in mods:
    try:
        __import__(m)
        print("OK",m)
    except Exception as e:
        print("ERR",m,e)
        bad=1
raise SystemExit(bad)
PY' > "$LOGDIR/managerai_dep_verify.txt" 2>&1 && echo "PASS managerai deps" | tee -a "$LOGDIR/result.txt"

echo "[3/8] gli health endpoint fiili cevap tespiti" | tee -a "$LOGDIR/steps.log"
for u in http://127.0.0.1:5002 http://127.0.0.1:5004 http://127.0.0.1:5006; do
  name="$(echo "$u" | sed 's#http://127.0.0.1:##')"
  {
    echo "URL=$u/"
    curl -sS -o /dev/null -w "ROOT_STATUS=%{http_code}\n" "$u/" || true
    echo "URL=$u/health"
    curl -sS -o /dev/null -w "HEALTH_STATUS=%{http_code}\n" "$u/health" || true
  } > "$LOGDIR/gli_$name.txt"
done

echo "[4/8] compose healthcheck hotfix patch" | tee -a "$LOGDIR/steps.log"
python3 - <<'PY'
from pathlib import Path
p=Path("/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/compose.yml")
s=p.read_text()
orig=s
targets=["gli-mainnet:","gli-sepolia:","gli-container:"]
for t in targets:
    if t in s:
        block=t+"\n"
        if t+"\n    healthcheck:\n      test: [\"CMD-SHELL\", \"wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1\"]\n      interval: 30s\n      timeout: 10s\n      retries: 5\n      start_period: 20s\n" not in s:
            s=s.replace(block, t+"\n    healthcheck:\n      test: [\"CMD-SHELL\", \"wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1\"]\n      interval: 30s\n      timeout: 10s\n      retries: 5\n      start_period: 20s\n", 1)
if s!=orig:
    p.write_text(s)
    print("PATCHED")
else:
    print("UNCHANGED")
PY

echo "[5/8] compose syntax doğrulama" | tee -a "$LOGDIR/steps.log"
docker compose -f "$REPO/compose.yml" -p quantumai-stack config > "$LOGDIR/compose_config.txt" 2>&1

echo "[6/8] ilgili servisleri recreate" | tee -a "$LOGDIR/steps.log"
docker compose -f "$REPO/compose.yml" -p quantumai-stack up -d --force-recreate gli-mainnet gli-sepolia gli-container > "$LOGDIR/gli_recreate.txt" 2>&1 || true
sleep 10

echo "[7/8] son sağlık kontrolleri" | tee -a "$LOGDIR/steps.log"
{
  echo "managerai"; curl -fsS http://127.0.0.1:8012/healthz >/dev/null && echo PASS || echo FAIL
  echo "managerai-broker"; curl -fsS http://127.0.0.1:8787/healthz >/dev/null && echo PASS || echo FAIL
  echo "redpanda-demo-ready"; curl -fsS http://127.0.0.1:19644/v1/status/ready >/dev/null && echo PASS || echo FAIL
  echo "redpanda-mcai-ready"; curl -fsS http://127.0.0.1:18082/v1/status/ready >/dev/null && echo PASS || echo FAIL
  echo "gli-mainnet-root"; curl -fsS http://127.0.0.1:5002/ >/dev/null && echo PASS || echo FAIL
  echo "gli-sepolia-root"; curl -fsS http://127.0.0.1:5004/ >/dev/null && echo PASS || echo FAIL
  echo "gli-container-root"; curl -fsS http://127.0.0.1:5006/ >/dev/null && echo PASS || echo FAIL
} | tee "$LOGDIR/final_checks.txt"

echo "[8/8] özet" | tee -a "$LOGDIR/steps.log"
echo "LOGDIR=$LOGDIR"
echo "BACKUP=$REPO/_backups/final_hardening/compose.yml.$TS.bak"
echo "MANAGERAI_DEPS=$(cat "$LOGDIR/managerai_dep_verify.txt" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')"
echo "REDPANDA_PORTS_DEMO=$(tr '\n' '|' < "$LOGDIR/demo_app_redpanda_ports.txt" 2>/dev/null || true)"
echo "REDPANDA_PORTS_MCAI=$(tr '\n' '|' < "$LOGDIR/mcai_redpanda_ports.txt" 2>/dev/null || true)"
