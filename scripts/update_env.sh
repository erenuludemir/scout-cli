#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-.env}"
umask 077
touch "$ENV_FILE"
chmod 600 "$ENV_FILE"

ensure_placeholder() {
  local key="$1"
  local placeholder="$2"

  if ! grep -q "^${key}=" "$ENV_FILE"; then
    printf '%s=%s\n' "$key" "$placeholder" >> "$ENV_FILE"
  fi
}

ensure_placeholder "ETHERSCAN_API_KEY" "__YOUR_ETHERSCAN_API_KEY__"
ensure_placeholder "INFURA_PROJECT_ID" "__YOUR_INFURA_PROJECT_ID__"
ensure_placeholder "ETH_SENDER_ADDRESS" "__YOUR_WALLET_ADDRESS__"
ensure_placeholder "ETH_PRIVATE_KEY" "__YOUR_PRIVATE_KEY__"
ensure_placeholder "ETH_RECIPIENT_ADDRESS" "__RECEIVER_WALLET_ADDRESS__"

echo "[OK] Missing Ethereum settings were added to $ENV_FILE as placeholders."
