#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
PLIST_SRC="$ROOT/macos/com.quantumai.managerai.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.quantumai.managerai.plist"

mkdir -p "$HOME/Library/LaunchAgents" "$ROOT/_logs/managerai"
cp "$PLIST_SRC" "$PLIST_DST"
chmod 644 "$PLIST_DST"

launchctl bootout "gui/$(id -u)" "$PLIST_DST" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_DST"
launchctl kickstart -k "gui/$(id -u)/com.quantumai.managerai"
launchctl print "gui/$(id -u)/com.quantumai.managerai" || true
