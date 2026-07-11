#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
OUT="$ROOT/_reports/repair_runbook/codebuild_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"

xcodebuild \
  -project "$ROOT/ios/QuantumAIMobileApp/QuantumAIMobileApp.xcodeproj" \
  -scheme "QuantumAIMobileApp" \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build \
  > "$OUT/build.log" 2>&1 || true

grep -nE 'error:|warning:|multiple producers|RawTransaction|signTRON|watchlist|outbox|appendAudit|flushOutbox|queueForBroadcast|LoginView|SummaryStatCard|TerminalStatCard|PerformanceChart|BinanceAdapter' "$OUT/build.log" \
  > "$OUT/key_matches.log" || true

printf '%s\n' "$OUT"
