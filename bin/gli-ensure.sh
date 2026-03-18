#!/usr/bin/env bash
set -euo pipefail
APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"
CTR="${CTR:-gli-container}"
HOST_PORT="${HOST_PORT:-5002}"
if [[ -f "$APP_DIR/.runmode" ]]&&grep -qx "host" "$APP_DIR/.runmode";then
  curl -fsS "http://127.0.0.1:${HOST_PORT}/" >/dev/null 2>&1||{ launchctl unload "$HOME/Library/LaunchAgents/com.${USER}.gli.host.plist" >/dev/null 2>&1||true; launchctl load "$HOME/Library/LaunchAgents/com.${USER}.gli.host.plist" >/dev/null 2>&1||true; }
else
  if ! docker ps --format '{{.Names}}' | grep -qx "$CTR";then
    docker rm -f "$CTR" >/dev/null 2>&1||true
    docker run -d --name "$CTR" --env-file "$APP_DIR/.env" -p "${HOST_PORT}:5002" --restart=unless-stopped --health-cmd='curl -sf http://127.0.0.1:5002/ || exit 1' --health-interval=20s --health-timeout=5s --health-retries=5 "${IMAGE:-erenuludemir/gli-app:fixed}"
  fi
fi
