#!/usr/bin/env bash
set -Eeuo pipefail
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$PROJECT_DIR"
export PROJECT_DIR
exec "$PROJECT_DIR/ops/qai_compose_hardening_autofix.sh"
