#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${COLIMA_PROFILE:-mcai-colima}"
export DOCKER_HOST="${DOCKER_HOST:-unix://$HOME/.colima/${PROFILE}/docker.sock}"

bash "$ROOT/ops/qai_stack_ops.sh" down all || true

printf 'ROLLBACK_DONE\n'
