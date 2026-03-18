#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${COLIMA_PROFILE:-mcai-colima}"
export DOCKER_HOST="${DOCKER_HOST:-unix://$HOME/.colima/${PROFILE}/docker.sock}"

MASTER_FILES=(-f "$ROOT/compose.master.yml")
MAIN_FILES=(-f "$ROOT/compose.yml" -f "$ROOT/compose.override.yml")
BASE_FILES=(-f "$ROOT/docker-compose.base.yml" -f "$ROOT/docker-compose.override.yml")

TMPDIR_QAI="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_QAI"' EXIT

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "MISSING:$1" >&2
    exit 1
  }
}

need docker
need curl
need python3

dc_ps_json() {
  local name="$1"
  shift
  docker compose "$@" ps --format json > "$TMPDIR_QAI/${name}.json"
}

probe() {
  local name="$1"
  local url="$2"
  local body_file="$TMPDIR_QAI/${name}.body"
  local code
  code="$(curl -sS -o "$body_file" -w '%{http_code}' "$url" || true)"
  printf '%s\n' "$code" > "$TMPDIR_QAI/${name}.code"
}

dc_ps_json master "${MASTER_FILES[@]}"
dc_ps_json main "${MAIN_FILES[@]}"
dc_ps_json base "${BASE_FILES[@]}"

probe gateway_health "http://127.0.0.1:5003/health"
probe gateway_root "http://127.0.0.1:5003/"
probe gli_mainnet "http://127.0.0.1:5002/"
probe gli_sepolia "http://127.0.0.1:5004/"
probe gli_default "http://127.0.0.1:5006/"
probe usdt_v2_health "http://127.0.0.1:5005/health"
probe usdt_v2_root "http://127.0.0.1:5005/"

if [ -n "${LINEAR_API_KEY:-}" ]; then
  bash "$ROOT/ops/qai_linear_smoke.sh" > "$TMPDIR_QAI/linear.json" || true
fi

python3 - <<'PY' "$TMPDIR_QAI"
import json
import os
import sys
from pathlib import Path

tmp = Path(sys.argv[1])


def load_json(name):
    p = tmp / f"{name}.json"
    try:
        text = p.read_text().strip()
    except Exception:
        return []

    if not text:
        return []

    try:
        data = json.loads(text)
        return data if isinstance(data, list) else [data]
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


def load_code(name):
    p = tmp / f"{name}.code"
    return p.read_text().strip() if p.exists() else "000"


def load_body(name):
    p = tmp / f"{name}.body"
    if not p.exists():
        return ""
    text = p.read_text(errors="replace").strip()
    return text[:400]


def load_optional_json(name):
    p = tmp / f"{name}.json"
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text().strip())
    except Exception:
        return None


summary = {
    "ok": True,
    "docker_host": os.environ.get("DOCKER_HOST", ""),
    "stacks": {
        "master": load_json("master"),
        "main": load_json("main"),
        "base": load_json("base"),
    },
    "http": {
        "gateway_health": {"code": load_code("gateway_health"), "body": load_body("gateway_health")},
        "gateway_root": {"code": load_code("gateway_root"), "body": load_body("gateway_root")},
        "gli_mainnet": {"code": load_code("gli_mainnet"), "body": load_body("gli_mainnet")},
        "gli_sepolia": {"code": load_code("gli_sepolia"), "body": load_body("gli_sepolia")},
        "gli_default": {"code": load_code("gli_default"), "body": load_body("gli_default")},
        "usdt_v2_health": {"code": load_code("usdt_v2_health"), "body": load_body("usdt_v2_health")},
        "usdt_v2_root": {"code": load_code("usdt_v2_root"), "body": load_body("usdt_v2_root")},
    },
    "linear": load_optional_json("linear"),
    "problems": [],
}

for stack_name, items in summary["stacks"].items():
    for item in items:
        state = str(item.get("State", ""))
        health = str(item.get("Health", ""))
        service = str(item.get("Service", ""))
        if state.lower() != "running":
            summary["ok"] = False
            summary["problems"].append(f"{stack_name}:{service}:state={state}")
        if health and health.lower() not in {"healthy", "running"}:
            summary["ok"] = False
            summary["problems"].append(f"{stack_name}:{service}:health={health}")

for name, payload in summary["http"].items():
    if payload["code"] != "200":
        summary["ok"] = False
        summary["problems"].append(f"http:{name}:code={payload['code']}")

if isinstance(summary["linear"], dict) and summary["linear"].get("enabled") and not summary["linear"].get("ok"):
    summary["ok"] = False
    summary["problems"].append(f"linear:error={summary['linear'].get('error', 'unknown')}")

print(json.dumps(summary, ensure_ascii=False, indent=2))
raise SystemExit(0 if summary["ok"] else 1)
PY
