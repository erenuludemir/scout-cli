#!/usr/bin/env bash
set -euo pipefail
APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"; HOST_PORT="${HOST_PORT:-5002}"; CTR="${CTR:-gli-container}"; IMAGE="${IMAGE:-erenuludemir/gli-app:fixed}"
cd "$APP_DIR"
perl -0777 -pe 's/^USDT_CONTRACT_ADDRESS=.*/USDT_CONTRACT_ADDRESS=0xE970e908cbc61123D067D54Da9A0d8Ff56DfcDBA/m' -i .env || true
if [[ -f ".runmode" ]] && grep -qx "host" .runmode; then
  launchctl unload "$HOME/Library/LaunchAgents/com.${USER}.gli.host.plist" >/dev/null 2>&1 || true
  launchctl load   "$HOME/Library/LaunchAgents/com.${USER}.gli.host.plist" >/dev/null 2>&1 || true
else
  docker rm -f "$CTR" >/dev/null 2>&1 || true
  docker build -t "$IMAGE" .
  docker run -d --name "$CTR" --env-file "$APP_DIR/.env" -p "${HOST_PORT}:5002" --restart=unless-stopped "$IMAGE"
fi
