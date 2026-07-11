#!/usr/bin/env bash
set -euo pipefail
while true; do
  date '+%F %T'
  curl -fsS http://127.0.0.1:8012/health || echo "managerai_health_fail"
  echo
  curl -fsS http://127.0.0.1:8787/health || echo "broker_health_fail"
  echo
  docker ps --format '{{.Names}} {{.Status}}' | egrep 'managerai|autoheal|watchtower|gateway|rosettaai|quantumai-usdt-v2|mcai' || true
  echo "-----"
  sleep 15
done
