#!/usr/bin/env bash
set -euo pipefail
ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$ROOT/_logs/bootstrap/$TS"
mkdir -p "$OUT"
cd "$ROOT"

echo "== DIRENV ==" | tee "$OUT/summary.txt"
command -v direnv >/dev/null 2>&1 && direnv allow "$ROOT" >> "$OUT/summary.txt" 2>&1 || true
eval "$(direnv export zsh)" >/dev/null 2>&1 || true

echo "== PYTHON SAFE ENV ==" | tee -a "$OUT/summary.txt"
export VIRTUAL_ENV="$ROOT/.venv"
export PATH="$VIRTUAL_ENV/bin:$PATH"
python3 -V | tee -a "$OUT/summary.txt"
[ -x "$ROOT/.venv/bin/python" ] && "$ROOT/.venv/bin/python" -V | tee -a "$OUT/summary.txt" || true
[ -x "$ROOT/.venv/bin/pip" ] && "$ROOT/.venv/bin/pip" list --format=columns > "$OUT/pip_list.txt" 2>&1 || true

echo "== DOCKER SNAPSHOT ==" | tee -a "$OUT/summary.txt"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' > "$OUT/docker_ps.txt"
docker stats --no-stream > "$OUT/docker_stats.txt" || true
docker compose -f "$ROOT/compose.yml" --project-name quantumai-stack ps > "$OUT/compose_ps.txt" 2>&1 || true

echo "== CONTAINER HEALTH ==" | tee -a "$OUT/summary.txt"
for n in \
managerai managerai-broker managerai-guard \
quantumai-stack-gateway-1 quantumai-usdt-v2 quantumai-stack-rosettaai-1 \
quantumai-stack-metrics-1 quantumai-stack-prometheus-1 quantumai-stack-grafana-1 \
quantumai-stack-demo-app-redis-1 quantumai-stack-demo-app-redpanda-1 \
quantumai-stack-mcai-redis-1 quantumai-stack-mcai-redpanda-1 \
quantumai-stack-mcai-api-1 quantumai-stack-mcai-feeder-1 quantumai-stack-mcai-router-1 \
quantumai-stack-mcai-sim-1 quantumai-stack-mcai-large-exec-1 quantumai-stack-mcai-small-agg-1 \
quantumai-stack-mcai-risk-1 quantumai-stack-mcai-trade-engine-1 \
gli-mainnet gli-sepolia gli-container autoheal watchtower
do
  docker inspect "$n" > "$OUT/$n.inspect.json" 2>/dev/null || true
  docker logs --tail 200 "$n" > "$OUT/$n.logs.txt" 2>&1 || true
done

echo "== HTTP HEALTH ==" | tee -a "$OUT/summary.txt"
curl -fsS http://127.0.0.1:8012/health > "$OUT/managerai.health.json" 2>"$OUT/managerai.health.err" || true
curl -fsS http://127.0.0.1:8787/health > "$OUT/managerai_broker.health.json" 2>"$OUT/managerai_broker.health.err" || true
curl -fsS http://127.0.0.1:5003/health > "$OUT/gateway.health.json" 2>"$OUT/gateway.health.err" || true
curl -fsS http://127.0.0.1:5005/health > "$OUT/usdt_v2.health.json" 2>"$OUT/usdt_v2.health.err" || true
curl -fsS http://127.0.0.1:5090/health > "$OUT/rosettaai.health.json" 2>"$OUT/rosettaai.health.err" || true
curl -fsS http://127.0.0.1:9100/metrics > "$OUT/metrics.prom" 2>"$OUT/metrics.err" || true
curl -fsS http://127.0.0.1:9090/-/healthy > "$OUT/prometheus.healthy.txt" 2>"$OUT/prometheus.err" || true
curl -fsS http://127.0.0.1:3000/api/health > "$OUT/grafana.health.json" 2>"$OUT/grafana.health.err" || true
curl -fsS http://127.0.0.1:18100/health > "$OUT/mcai_api.health.json" 2>"$OUT/mcai_api.health.err" || true
curl -fsS http://127.0.0.1:18101/health > "$OUT/mcai_feeder.health.json" 2>"$OUT/mcai_feeder.health.err" || true
curl -fsS http://127.0.0.1:18102/health > "$OUT/mcai_router.health.json" 2>"$OUT/mcai_router.health.err" || true
curl -fsS http://127.0.0.1:18103/health > "$OUT/mcai_sim.health.json" 2>"$OUT/mcai_sim.health.err" || true
curl -fsS http://127.0.0.1:18104/health > "$OUT/mcai_large_exec.health.json" 2>"$OUT/mcai_large_exec.health.err" || true
curl -fsS http://127.0.0.1:18105/health > "$OUT/mcai_risk.health.json" 2>"$OUT/mcai_risk.health.err" || true
curl -fsS http://127.0.0.1:18106/health > "$OUT/mcai_small_agg.health.json" 2>"$OUT/mcai_small_agg.health.err" || true
curl -fsS http://127.0.0.1:18107/health > "$OUT/mcai_trade_engine.health.json" 2>"$OUT/mcai_trade_engine.health.err" || true

echo "== MANAGERAI WORKFLOW CHECK ==" | tee -a "$OUT/summary.txt"
curl -fsS http://127.0.0.1:8012/ > "$OUT/managerai.root.json" 2>"$OUT/managerai.root.err" || true
curl -fsS http://127.0.0.1:8787/ > "$OUT/managerai_broker.root.json" 2>"$OUT/managerai_broker.root.err" || true

echo "== CONTROLLED RESTART OF MANAGERAI LAYER ==" | tee -a "$OUT/summary.txt"
docker restart managerai-broker managerai-guard managerai >> "$OUT/summary.txt" 2>&1 || true
sleep 8
curl -fsS http://127.0.0.1:8787/health > "$OUT/managerai_broker.health.after_restart.json" 2>"$OUT/managerai_broker.health.after_restart.err" || true
curl -fsS http://127.0.0.1:8012/health > "$OUT/managerai.health.after_restart.json" 2>"$OUT/managerai.health.after_restart.err" || true

echo "== RESOURCE CONFLICT MAP ==" | tee -a "$OUT/summary.txt"
{
  echo "REDIS_CONTAINERS"
  docker ps --format '{{.Names}}\t{{.Ports}}' | grep -i redis || true
  echo
  echo "REDPANDA_CONTAINERS"
  docker ps --format '{{.Names}}\t{{.Ports}}' | grep -i redpanda || true
  echo
  echo "POSTGRES_CONTAINERS"
  docker ps --format '{{.Names}}\t{{.Ports}}' | grep -i postgres || true
} > "$OUT/resource_conflicts.txt"

echo "== FINAL ==" | tee -a "$OUT/summary.txt"
echo "$OUT" | tee -a "$OUT/summary.txt"
