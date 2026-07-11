#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${COLIMA_PROFILE:-mcai-colima}"
export DOCKER_HOST="${DOCKER_HOST:-unix://$HOME/.colima/${PROFILE}/docker.sock}"
unset COMPOSE_FILE

UNIFIED_FILES=(-f "$ROOT/compose.yml" -f "$ROOT/compose.override.yml")

LOG_ROOT="$ROOT/_logs/health"
TS="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="$LOG_ROOT/project_health_$TS"
TAIL_LINES="${TAIL_LINES:-200}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "MISSING:$1" >&2
    exit 1
  }
}

dc() { docker compose "${UNIFIED_FILES[@]}" "$@"; }

write_ps_json() { dc ps --format json > "$RUN_DIR/unified_ps.json"; }

write_ids() { dc ps -q | sed '/^$/d' > "$RUN_DIR/unified_ids.txt"; }

write_logs() { dc logs --tail="$TAIL_LINES" > "$RUN_DIR/unified_logs.log" 2>&1 || true; }

probe() {
  local name="$1"
  local url="$2"
  local body_file="$RUN_DIR/${name}.body"
  local code
  code="$(curl -sS -o "$body_file" -w '%{http_code}' "$url" || true)"
  printf '%s\n' "$code" > "$RUN_DIR/${name}.code"
  printf '%s %s\n' "$code" "$url" >> "$RUN_DIR/http_checks.log"
}

need docker
need curl
need python3

if ! docker info >/dev/null 2>&1; then
  if command -v colima >/dev/null 2>&1; then
    colima start >/dev/null 2>&1 || true
  fi
fi

docker info >/dev/null 2>&1 || {
  echo "DOCKER_DAEMON_CALISMIYOR" >&2
  exit 1
}

mkdir -p "$RUN_DIR"
docker info --format 'ServerVersion={{.ServerVersion}} Driver={{.Driver}} CgroupVersion={{.CgroupVersion}}' \
  > "$RUN_DIR/docker_info.txt"

write_ps_json
write_ids
write_logs

cp "$RUN_DIR/unified_ids.txt" "$RUN_DIR/all_ids.txt"

if [ -s "$RUN_DIR/all_ids.txt" ]; then
  while read -r cid; do
    docker inspect "$cid" --format '{{.Name}} {{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}} {{.State.Status}} {{.RestartCount}}'
  done < "$RUN_DIR/all_ids.txt" | sed 's#^/##' > "$RUN_DIR/inspect_health.log"

  docker stats --no-stream \
    --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}' \
    $(tr '\n' ' ' < "$RUN_DIR/all_ids.txt") > "$RUN_DIR/docker_stats.log"
else
  : > "$RUN_DIR/inspect_health.log"
  printf 'NO_CONTAINERS\n' > "$RUN_DIR/docker_stats.log"
fi

: > "$RUN_DIR/http_checks.log"
probe gateway_health "http://127.0.0.1:5003/health"
probe gateway_root "http://127.0.0.1:5003/"
probe gateway_dex_pairs "http://127.0.0.1:5003/dex/pairs"
probe gateway_usdt_root "http://127.0.0.1:5003/usdt/"
probe gateway_v2_health "http://127.0.0.1:5003/v2/health"
probe gateway_ai_health "http://127.0.0.1:5003/ai/health"
probe usdt_v2_health "http://127.0.0.1:5005/health"
probe usdt_v2_root "http://127.0.0.1:5005/"
probe rosettaai_health "http://127.0.0.1:5090/health"
probe rosettaai_model "http://127.0.0.1:5090/model"
probe metrics_health "http://127.0.0.1:9100/health"
probe metrics_prometheus "http://127.0.0.1:9100/metrics"
probe gli_mainnet "http://127.0.0.1:5002/"
probe gli_sepolia "http://127.0.0.1:5004/"
probe gli_default "http://127.0.0.1:5006/"

python3 - <<'PY' "$RUN_DIR"
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])


def load_json(path: Path):
    try:
        text = path.read_text().strip()
    except Exception:
        return []
    if not text:
        return []
    try:
        data = json.loads(text)
    except Exception:
        items = []
        for line in text.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                items.append(json.loads(line))
            except Exception:
                pass
        return items
    return data if isinstance(data, list) else [data]


def load_text(path: Path) -> str:
    try:
        return path.read_text().strip()
    except Exception:
        return ""


def load_body(name: str) -> str:
    text = load_text(run_dir / f"{name}.body")
    return text[:400]


def load_code(name: str) -> str:
    code = load_text(run_dir / f"{name}.code")
    return code or "000"


docker_info = load_text(run_dir / "docker_info.txt")
stacks = {"unified": load_json(run_dir / "unified_ps.json")}
http_names = [
    "gateway_health",
    "gateway_root",
    "gateway_dex_pairs",
    "gateway_usdt_root",
    "gateway_v2_health",
    "gateway_ai_health",
    "usdt_v2_health",
    "usdt_v2_root",
    "rosettaai_health",
    "rosettaai_model",
    "metrics_health",
    "metrics_prometheus",
    "gli_mainnet",
    "gli_sepolia",
    "gli_default",
]
http = {name: {"code": load_code(name), "body": load_body(name)} for name in http_names}

summary = {
    "ok": True,
    "scope": "unified-project-only",
    "docker_info": docker_info,
    "log_dir": str(run_dir),
    "stacks": stacks,
    "http": http,
    "problems": [],
}

for stack_name, items in stacks.items():
    for item in items:
        state = str(item.get("State", "")).lower()
        health = str(item.get("Health", "")).lower()
        service = str(item.get("Service", ""))
        if state != "running":
            summary["ok"] = False
            summary["problems"].append(f"{stack_name}:{service}:state={state or 'unknown'}")
        if health and health not in {"healthy", "running"}:
            summary["ok"] = False
            summary["problems"].append(f"{stack_name}:{service}:health={health}")

for name, payload in http.items():
    if payload["code"] != "200":
        summary["ok"] = False
        summary["problems"].append(f"http:{name}:code={payload['code']}")

(run_dir / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n")

lines = [
    "===== PROJECT_HEALTH =====",
    f"SCOPE:{summary['scope']}",
    f"DOCKER:{docker_info}",
    f"RESULT:{'SAGLIKLI' if summary['ok'] else 'SORUN_VAR'}",
    "",
    "===== STACK_OVERVIEW =====",
]

for stack_name, items in stacks.items():
    lines.append(f"[{stack_name}]")
    if not items:
        lines.append("  no-containers")
        continue
    for item in items:
        service = item.get("Service", "")
        status = item.get("Status", "")
        lines.append(f"  {service}: {status}")

lines.extend(["", "===== HTTP_CHECKS ====="])
for name in http_names:
    payload = http[name]
    lines.append(f"{name}: {payload['code']}")

lines.extend(["", "===== PROBLEMS ====="])
if summary["problems"]:
    lines.extend(summary["problems"])
else:
    lines.append("none")

lines.extend(["", f"LOG_DIR:{run_dir}"])
(run_dir / "summary.txt").write_text("\n".join(lines) + "\n")
print((run_dir / "summary.txt").read_text(), end="")
raise SystemExit(0 if summary["ok"] else 1)
PY
