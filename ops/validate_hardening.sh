#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
COMPOSE_MAIN="$REPO/compose.yml"
COMPOSE_OVERRIDE="$REPO/ops/compose.hardening.override.yml"
PROJECT="quantumai-stack"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="$REPO/_logs/hardening/validate_$TS.log"

{
  echo "=== STACK ==="
  docker compose -f "$COMPOSE_MAIN" -f "$COMPOSE_OVERRIDE" -p "$PROJECT" ps
  echo
  echo "=== HEALTH ==="
  for u in \
    "http://127.0.0.1:8012/healthz" \
    "http://127.0.0.1:5003/health" \
    "http://127.0.0.1:9090/-/ready" \
    "http://127.0.0.1:19644/v1/status/ready" \
    "http://127.0.0.1:18082/v1/status/ready" \
    "http://127.0.0.1:9187/metrics"
  do
    code="$(curl -s -o /dev/null -w "%{http_code}" "$u" || true)"
    echo "$u -> ${code:-000}"
  done
  echo
  echo "=== WARNINGS ==="
  docker compose -f "$COMPOSE_MAIN" -f "$COMPOSE_OVERRIDE" -p "$PROJECT" logs --tail 250 prometheus postgres-exporter demo-app-redpanda mcai-redpanda gli gli-mainnet gli-sepolia 2>&1 | grep -Ei '\bWARN\b|\bERROR\b|failed|exception|traceback|corrupt|tsdb|worker .* exited|insecure' || true
} | tee "$OUT"

echo "VALIDATION_LOG=$OUT"
