#!/bin/bash
set -e

PLIST_PATH=~/Library/LaunchAgents/com.quantumai.transfer.plist
cp ./launchd/com.quantumai.transfer.plist "$PLIST_PATH"

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "🚀 QuantumAI GUI now auto-starts at login!"
