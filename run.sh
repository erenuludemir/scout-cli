#!/usr/bin/env bash
set -euo pipefail

load_etherscan_api_key() {
  if [ -z "${ETHERSCAN_API_KEY:-}" ] && [ -n "${API_KEY_ETHERSCAN:-}" ]; then
    export ETHERSCAN_API_KEY="${API_KEY_ETHERSCAN}"
  fi

  if [ -z "${ETHERSCAN_API_KEY:-}" ]; then
    for env_file in .env .env.local; do
      if [ -f "$env_file" ]; then
        value="$(grep -E '^ETHERSCAN_API_KEY=' "$env_file" | tail -n 1 | cut -d= -f2- || true)"
        if [ -n "$value" ]; then
          export ETHERSCAN_API_KEY="$value"
          break
        fi
      fi
    done
  fi
}

if [ "${1:-}" = "balance-check" ]; then
  shift
  load_etherscan_api_key
  exec python3 tools/etherscan/eth_balance_tracker.py "${1:-0x71c7656ec7ab88b098defb751b7401b5f6d8976f}" "${2:-1}"
fi

if [ "${1:-}" = "balance-txlist" ]; then
  shift
  load_etherscan_api_key
  exec python3 tools/etherscan/eth_activity_tracker.py txlist "${1:-0x71c7656ec7ab88b098defb751b7401b5f6d8976f}" "${2:-1}" "${3:-1}" "${4:-10}" "${5:-desc}"
fi

if [ "${1:-}" = "balance-tokentx" ]; then
  shift
  load_etherscan_api_key
  exec python3 tools/etherscan/eth_activity_tracker.py tokentx "${1:-0x71c7656ec7ab88b098defb751b7401b5f6d8976f}" "${2:-1}" "${3:-}" "${4:-1}" "${5:-10}" "${6:-desc}"
fi

if [ "${1:-}" = "balance-portfolio" ]; then
  shift
  load_etherscan_api_key
  address="${1:-0x71c7656ec7ab88b098defb751b7401b5f6d8976f}"
  chainid="${2:-1}"
  contracts="${3:-}"

  if output="$(python3 tools/etherscan/eth_activity_tracker.py portfolio "$address" "$chainid" 2>&1)"; then
    printf '%s\n' "$output"
    exit 0
  fi

  if printf '%s' "$output" | grep -q 'API Pro endpoint'; then
    exec python3 tools/etherscan/eth_portfolio_fallback.py "$address" "$chainid" "$contracts"
  fi

  printf '%s\n' "$output"
  exit 1
fi

if [ "${1:-}" = "balance-portfolio-fallback" ]; then
  shift
  load_etherscan_api_key
  exec python3 tools/etherscan/eth_portfolio_fallback.py "${1:-0x71c7656ec7ab88b098defb751b7401b5f6d8976f}" "${2:-1}" "${3:-}"
fi

if [ "${1:-}" = "profit-scan" ]; then
  shift
  exec python3 tools/profitability/preview_profit_gate.py "${1:-USDT}" "${2:-ETH}" "${3:-100,250,500,1000}" "${4:-120}" "${5:-5}" "${6:-50}" "${7:-http://127.0.0.1:5003}"
fi

IMAGE_NAME="quantumai-usdt-v2"
CONTAINER_NAME="quantumai-usdt-v2-app"
PORT="${PORT:-5000}"

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

docker build -t "$IMAGE_NAME" .

docker run -d \
  --name "$CONTAINER_NAME" \
  -p "${PORT}:5000" \
  --env-file .env \
  "$IMAGE_NAME"

echo "RUNNING:http://127.0.0.1:${PORT}"
