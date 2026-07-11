#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
IOS_ROOT="$REPO/ios/QuantumAIMobile"
LOG_DIR="$REPO/_logs/ios_megapipeline"
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_DIR"

PACKAGE_DUMP="$LOG_DIR/${TS}_package_dump.json"
SWIFT_BUILD_LOG="$LOG_DIR/${TS}_swift_build.log"
SWIFT_TEST_LOG="$LOG_DIR/${TS}_swift_test.log"
REPORT_LOG="$LOG_DIR/${TS}_validate_report.log"

pushd "$IOS_ROOT" >/dev/null
swift package dump-package > "$PACKAGE_DUMP"
if swift build > "$SWIFT_BUILD_LOG" 2>&1; then
  BUILD_STATUS="OK"
else
  BUILD_STATUS="FAIL"
fi
if swift test > "$SWIFT_TEST_LOG" 2>&1; then
  TEST_STATUS="OK"
else
  TEST_STATUS="FAIL"
fi
popd >/dev/null

{
  echo "IOS_ROOT=$IOS_ROOT"
  echo "PACKAGE_DUMP=$PACKAGE_DUMP"
  echo "SWIFT_BUILD_LOG=$SWIFT_BUILD_LOG"
  echo "SWIFT_TEST_LOG=$SWIFT_TEST_LOG"
  echo "BUILD_STATUS=$BUILD_STATUS"
  echo "TEST_STATUS=$TEST_STATUS"
} | tee "$REPORT_LOG"

[ "$BUILD_STATUS" = "OK" ] && [ "$TEST_STATUS" = "OK" ]
