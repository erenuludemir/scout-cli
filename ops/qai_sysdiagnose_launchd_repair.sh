#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
cd "$ROOT"

exec python3 "$ROOT/ops/qai_sysdiagnose_launchd_repair.py" "$@"
