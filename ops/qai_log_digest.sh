#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
OUT="$ROOT/_reports/managerai/log_digest_$(date +%Y%m%d_%H%M%S).txt"

mkdir -p "$ROOT/_reports/managerai"

{
  echo "=== managerai logs ==="
  tail -n 200 "$ROOT/_logs/managerai/launchd_boot.log" 2>/dev/null || true
  echo
  tail -n 200 "$ROOT/_logs/managerai/launchd.err.log" 2>/dev/null || true
  echo
  tail -n 200 "$ROOT/_logs/managerai/resident_actions.jsonl" 2>/dev/null || true
  echo
  tail -n 200 "$ROOT/_logs/manager_ai/history.jsonl" 2>/dev/null || true
} >"$OUT"

cat "$OUT"
