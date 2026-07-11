#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
IOS_ROOT="$REPO/ios/QuantumAIMobile"
LOG_DIR="$REPO/_logs/ios_megapipeline"
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_DIR"

{
  echo "IOS_ROOT=$IOS_ROOT"
  echo "SWIFT_VERSION=$(swift --version 2>/dev/null | head -n1 || true)"
  echo "XCODESELECT=$(xcode-select -p 2>/dev/null || true)"
  test -f "$IOS_ROOT/Package.swift" && echo "PACKAGE=OK" || echo "PACKAGE=MISSING"
  test -f "$IOS_ROOT/QuantumAIMobile/AppShell/QuantumAIMobileApp.swift" && echo "APP_SHELL=OK" || echo "APP_SHELL=MISSING"
  test -f "$IOS_ROOT/QuantumAIMobile/Resources/FeatureFlags.plist" && echo "FLAGS=OK" || echo "FLAGS=MISSING"
  test -f "$IOS_ROOT/QuantumAIMobileTests/BotTests.swift" && echo "TESTS=OK" || echo "TESTS=MISSING"
} | tee "$LOG_DIR/${TS}_install_check.log"

echo "REPORT=$LOG_DIR/${TS}_install_check.log"
