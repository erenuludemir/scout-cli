#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INTERVAL="${1:-30}"

while true; do
  date '+%Y-%m-%d %H:%M:%S'
  bash "$ROOT/ops/qai_health_summary.sh" || true
  sleep "$INTERVAL"
done
