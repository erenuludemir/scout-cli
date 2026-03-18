#!/bin/bash
set -euo pipefail
APP_ROOT="${APP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
QAI_DIR="${APP_ROOT}/.qai"
"${QAI_DIR}/qai-manage.sh" &
"${QAI_DIR}/qai-train-self-agent.sh" &
wait
