#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$HOME/Library/LaunchAgents/com.qai.colima-sysctl.plist"

mkdir -p "$ROOT/_logs" "$HOME/Library/LaunchAgents"
cp "$ROOT/ops/com.qai.colima-sysctl.plist" "$TARGET"

launchctl unload "$TARGET" >/dev/null 2>&1 || true
launchctl load -w "$TARGET"

printf 'LAUNCHAGENT_INSTALLED=%s\n' "$TARGET"
