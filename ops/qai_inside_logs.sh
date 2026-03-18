#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINES="${LINES:-50}"
FOLLOW="${FOLLOW:-0}"
SERVICE="${1:-all}"

usage() {
  cat <<'TXT'
USAGE:
  qai_inside_logs.sh <all|gateway|dex|usdt|usdt-v2|gli|gli-mainnet|gli-sepolia>

ENV:
  LINES=100   Tail line count (default: 50)
  FOLLOW=1    Stream logs with tail -f
TXT
}

compose_main() {
  docker compose -f "$ROOT/compose.yml" -f "$ROOT/compose.override.yml" "$@"
}

compose_master() {
  docker compose -f "$ROOT/compose.master.yml" "$@"
}

compose_base() {
  docker compose -f "$ROOT/docker-compose.base.yml" -f "$ROOT/docker-compose.override.yml" "$@"
}

show_logs() {
  local stack="$1"
  local compose_service="$2"
  shift 2
  local files=("$@")
  local cid=""
  local tail_args=(-n "$LINES")

  if [[ "$FOLLOW" == "1" ]]; then
    tail_args+=(-f)
  fi

  case "$stack" in
    main) cid="$(compose_main ps -q "$compose_service")" ;;
    master) cid="$(compose_master ps -q "$compose_service")" ;;
    base) cid="$(compose_base ps -q "$compose_service")" ;;
    *)
      echo "INVALID_STACK:$stack" >&2
      exit 1
      ;;
  esac

  if [[ -z "$cid" ]]; then
    echo "SERVICE_NOT_RUNNING:$compose_service" >&2
    return 1
  fi

  for file in "${files[@]}"; do
    echo "== $compose_service :: $file =="
    docker exec "$cid" sh -lc "
      ls -l '$file'
      target=\$(readlink '$file' 2>/dev/null || true)
      if [ \"\$target\" = '/dev/stdout' ] || [ \"\$target\" = '/dev/stderr' ]; then
        echo 'SKIP: target is still linked to' \"\$target\"
        exit 0
      fi
      tail ${tail_args[*]} '$file'
    "
    echo
  done
}

case "$SERVICE" in
  all)
    show_logs main gateway /var/log/nginx/access.log /var/log/nginx/error.log
    show_logs main dex /var/log/qai/access.log /var/log/qai/error.log
    show_logs main quantumai-usdt /var/log/qai/access.log /var/log/qai/error.log
    show_logs base quantumai-usdt-v2 /var/log/qai/access.log /var/log/qai/error.log
    show_logs master gli /var/log/qai/access.log /var/log/qai/error.log
    show_logs master gli-mainnet /var/log/qai/access.log /var/log/qai/error.log
    show_logs master gli-sepolia /var/log/qai/access.log /var/log/qai/error.log
    ;;
  gateway)
    show_logs main gateway /var/log/nginx/access.log /var/log/nginx/error.log
    ;;
  dex)
    show_logs main dex /var/log/qai/access.log /var/log/qai/error.log
    ;;
  usdt|quantumai-usdt)
    show_logs main quantumai-usdt /var/log/qai/access.log /var/log/qai/error.log
    ;;
  usdt-v2|v2|quantumai-usdt-v2)
    show_logs base quantumai-usdt-v2 /var/log/qai/access.log /var/log/qai/error.log
    ;;
  gli)
    show_logs master gli /var/log/qai/access.log /var/log/qai/error.log
    ;;
  gli-mainnet)
    show_logs master gli-mainnet /var/log/qai/access.log /var/log/qai/error.log
    ;;
  gli-sepolia)
    show_logs master gli-sepolia /var/log/qai/access.log /var/log/qai/error.log
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
