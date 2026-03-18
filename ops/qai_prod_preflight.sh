#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${COLIMA_PROFILE:-mcai-colima}"
export DOCKER_HOST="${DOCKER_HOST:-unix://$HOME/.colima/${PROFILE}/docker.sock}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "MISSING:$1" >&2
    exit 1
  }
}

need bash
need docker
need python3
need curl

for f in \
  "$ROOT/compose.master.yml" \
  "$ROOT/compose.yml" \
  "$ROOT/compose.override.yml" \
  "$ROOT/docker-compose.base.yml" \
  "$ROOT/docker-compose.override.yml" \
  "$ROOT/.env" \
  "$ROOT/.env.local" \
  "$ROOT/ops/qai_colima_sysctl.sh" \
  "$ROOT/ops/qai_stack_ops.sh" \
  "$ROOT/ops/qai_health_summary.sh"
do
  [ -f "$f" ] || {
    echo "MISSING_FILE:$f" >&2
    exit 1
  }
done

docker compose -f "$ROOT/compose.master.yml" config >/dev/null
docker compose -f "$ROOT/compose.yml" -f "$ROOT/compose.override.yml" config >/dev/null
docker compose -f "$ROOT/docker-compose.base.yml" -f "$ROOT/docker-compose.override.yml" config >/dev/null

python3 - "$ROOT" <<'PY'
import sys
from pathlib import Path

root = Path(sys.argv[1])
master = (root / "compose.master.yml").read_text(errors="replace")
main = (root / "compose.yml").read_text(errors="replace")
base = (root / "docker-compose.base.yml").read_text(errors="replace")

checks = {
    "compose.master.yml:name:quantumai-stack": "name: quantumai-stack" in master,
    "docker-compose.base.yml:name:quantumai-base": "name: quantumai-base" in base,
    "compose.master.yml:gunicorn": "gunicorn app:app" in (root / "gli" / "Dockerfile").read_text(errors="replace"),
    "quantumai-usdt-v2:gunicorn": "gunicorn app:app" in (root / "quantumai-usdt-v2" / "Dockerfile").read_text(errors="replace"),
}

bad = [k for k, v in checks.items() if not v]
if bad:
    raise SystemExit("PRECHECK_FAIL:" + ",".join(bad))

print("PRECHECK_OK")
PY

bash "$ROOT/ops/qai_health_summary.sh" >/dev/null || true

echo "PREFLIGHT_OK"
