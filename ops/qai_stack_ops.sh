#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${COLIMA_PROFILE:-mcai-colima}"
export DOCKER_HOST="${DOCKER_HOST:-unix://$HOME/.colima/${PROFILE}/docker.sock}"

MASTER_FILES=(-f "$ROOT/compose.master.yml")
MAIN_FILES=(-f "$ROOT/compose.yml" -f "$ROOT/compose.override.yml")
BASE_FILES=(-f "$ROOT/docker-compose.base.yml" -f "$ROOT/docker-compose.override.yml")

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "MISSING:$1" >&2
    exit 1
  }
}

need docker
need curl

run_dc() {
  local stack="$1"
  shift
  case "$stack" in
    master) docker compose "${MASTER_FILES[@]}" "$@" ;;
    main) docker compose "${MAIN_FILES[@]}" "$@" ;;
    base) docker compose "${BASE_FILES[@]}" "$@" ;;
    *)
      echo "INVALID_STACK:$stack" >&2
      exit 1
      ;;
  esac
}

health_one() {
  local label="$1"
  local url="$2"
  printf 'CHECK:%s:%s\n' "$label" "$url"
  curl -fsS "$url"
  printf '\n'
}

health_stack() {
  local stack="$1"
  case "$stack" in
    master)
      health_one "gli-mainnet" "http://127.0.0.1:5002/"
      health_one "gli-sepolia" "http://127.0.0.1:5004/"
      health_one "gli" "http://127.0.0.1:5006/"
      ;;
    main)
      health_one "gateway-health" "http://127.0.0.1:5003/health"
      health_one "gateway-root" "http://127.0.0.1:5003/"
      ;;
    base)
      health_one "usdt-v2-health" "http://127.0.0.1:5005/health"
      health_one "usdt-v2-root" "http://127.0.0.1:5005/"
      ;;
    all)
      health_stack master
      health_stack main
      health_stack base
      ;;
    *)
      echo "INVALID_STACK:$stack" >&2
      exit 1
      ;;
  esac
}

usage() {
  cat <<'TXT'
USAGE:
  qai_stack_ops.sh config <master|main|base|all>
  qai_stack_ops.sh build <master|main|base|all>
  qai_stack_ops.sh up <master|main|base|all>
  qai_stack_ops.sh down <master|main|base|all>
  qai_stack_ops.sh restart <master|main|base|all>
  qai_stack_ops.sh ps <master|main|base|all>
  qai_stack_ops.sh logs <master|main|base|all> [SERVICE]
  qai_stack_ops.sh health <master|main|base|all>
  qai_stack_ops.sh pull <master|main|base|all>
TXT
}

ACTION="${1:-}"
STACK="${2:-}"
SERVICE="${3:-}"

[ -n "$ACTION" ] || {
  usage
  exit 1
}
[ -n "$STACK" ] || {
  usage
  exit 1
}

case "$ACTION" in
  config)
    if [ "$STACK" = "all" ]; then
      run_dc master config
      run_dc main config
      run_dc base config
    else
      run_dc "$STACK" config
    fi
    ;;
  build)
    if [ "$STACK" = "all" ]; then
      run_dc master build
      run_dc main build
      run_dc base build
    else
      run_dc "$STACK" build
    fi
    ;;
  up)
    if [ "$STACK" = "all" ]; then
      run_dc master up -d --build
      run_dc main up -d --build
      run_dc base up -d --build
    else
      case "$STACK" in
        master|main|base) run_dc "$STACK" up -d --build ;;
        *)
          echo "INVALID_STACK:$STACK" >&2
          exit 1
          ;;
      esac
    fi
    ;;
  down)
    if [ "$STACK" = "all" ]; then
      run_dc base down --remove-orphans
      run_dc main down --remove-orphans
      run_dc master down --remove-orphans
    else
      run_dc "$STACK" down --remove-orphans
    fi
    ;;
  restart)
    if [ "$STACK" = "all" ]; then
      run_dc master restart
      run_dc main restart
      run_dc base restart
    else
      run_dc "$STACK" restart
    fi
    ;;
  ps)
    if [ "$STACK" = "all" ]; then
      run_dc master ps
      run_dc main ps
      run_dc base ps
    else
      run_dc "$STACK" ps
    fi
    ;;
  logs)
    if [ "$STACK" = "all" ]; then
      run_dc master logs --tail=100 ${SERVICE:+$SERVICE}
      run_dc main logs --tail=100 ${SERVICE:+$SERVICE}
      run_dc base logs --tail=100 ${SERVICE:+$SERVICE}
    else
      run_dc "$STACK" logs --tail=100 ${SERVICE:+$SERVICE}
    fi
    ;;
  health)
    health_stack "$STACK"
    ;;
  pull)
    if [ "$STACK" = "all" ]; then
      run_dc master pull || true
      run_dc main pull || true
      run_dc base pull || true
    else
      run_dc "$STACK" pull || true
    fi
    ;;
  *)
    usage
    exit 1
    ;;
esac
