#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
cd "$ROOT"

bash "$ROOT/ops/qai_manager_ai.sh" autopilot --apply --json
