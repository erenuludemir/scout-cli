#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
PROFILE="${COLIMA_PROFILE:-mcai-colima}"

export DOCKER_HOST="${DOCKER_HOST:-unix://$HOME/.colima/${PROFILE}/docker.sock}"

echo "=== launchctl ==="
launchctl print "gui/$(id -u)/com.quantumai.managerai" 2>/dev/null || true
echo
echo "=== state ==="
[ -f "$ROOT/_state/managerai/resident_state.json" ] && cat "$ROOT/_state/managerai/resident_state.json" || true
echo
echo "=== heartbeat ==="
[ -f "$ROOT/_state/managerai/heartbeat.json" ] && cat "$ROOT/_state/managerai/heartbeat.json" || true
echo
echo "=== broker health ==="
curl -fsS http://127.0.0.1:8787/health || true
echo
echo "=== compose ps ==="
bash "$ROOT/ops/qai_managerai_stack.sh" ps || true
echo
echo "=== diagnose ==="
bash "$ROOT/ops/qai_manager_ai.sh" diagnose --json || true
echo
echo "=== metrics inspect ==="
docker inspect quantumai-stack-metrics-1 2>/dev/null || true
echo
echo "=== metrics logs ==="
docker logs --tail 120 quantumai-stack-metrics-1 2>/dev/null || true
echo
echo "=== quantumai-usdt-v2 inspect ==="
docker inspect quantumai-usdt-v2 2>/dev/null || true
echo
echo "=== quantumai-usdt-v2 logs ==="
docker logs --tail 120 quantumai-usdt-v2 2>/dev/null || true
