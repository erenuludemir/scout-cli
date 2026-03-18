#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -n "${QAI_PYTHON:-}" ]; then
  PYTHON_BIN="${QAI_PYTHON}"
elif [ -x "$ROOT/.venv_qai_ai/bin/python" ]; then
  PYTHON_BIN="$ROOT/.venv_qai_ai/bin/python"
else
  PYTHON_BIN="python3"
fi

if [ -z "${LINEAR_API_KEY:-}" ]; then
  printf '%s\n' '{"ok":true,"enabled":false,"skipped":true,"reason":"LINEAR_API_KEY missing"}'
  exit 0
fi

"$PYTHON_BIN" - <<'PY'
import json
import os
import sys
from pathlib import Path

root = Path(os.getenv("QAI_ROOT", Path.cwd()))
sys.path.insert(0, str(root))

from integrations.linear.linear_client import LinearClient, LinearAPIError

try:
    client = LinearClient()
    viewer = client.health().get("viewer", {})
    teams = client.list_teams()
    print(json.dumps({
        "ok": True,
        "enabled": True,
        "viewer": viewer,
        "team_count": len(teams),
        "teams": teams[:10],
    }, ensure_ascii=False))
except Exception as exc:
    print(json.dumps({
        "ok": False,
        "enabled": True,
        "error": str(exc),
    }, ensure_ascii=False))
    raise SystemExit(1)
PY
