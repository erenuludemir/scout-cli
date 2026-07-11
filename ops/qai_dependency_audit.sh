#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
IOS_ROOT="$REPO/ios/QuantumAIMobile"
APP_ROOT="$IOS_ROOT/QuantumAIMobile"
TEST_ROOT="$IOS_ROOT/QuantumAIMobileTests"
COMPOSE_FILE="$REPO/compose.yml"
LOG_DIR="$REPO/_logs/dependency_audit"
TS="$(date +%Y%m%d_%H%M%S)"
FINAL_REPORT="$LOG_DIR/$TS.final_report.log"

mkdir -p "$LOG_DIR"

run_capture() {
  local outfile="$1"
  shift
  if "$@" >"$outfile" 2>&1; then
    return 0
  else
    return $?
  fi
}

unset DEVELOPER_DIR

if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
  sudo -n true >/dev/null 2>&1 || sudo -v
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer >/dev/null 2>&1 || true
  sudo xcodebuild -runFirstLaunch >/dev/null 2>&1 || true
fi

ACTIVE_DEV="$(xcode-select -p 2>/dev/null || true)"

cd "$IOS_ROOT"

chmod -R u+rw .build 2>/dev/null || true
find .build -mindepth 1 -maxdepth 1 -exec chmod -R u+rw {} \; 2>/dev/null || true
find .build -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
rm -rf .build 2>/dev/null || true

run_capture "$LOG_DIR/$TS.xcrun_swift.txt" /usr/bin/xcrun --find swift; XCRUN_SWIFT_RC=$?
run_capture "$LOG_DIR/$TS.xcrun_xcodebuild.txt" /usr/bin/xcrun --find xcodebuild; XCRUN_XCODEBUILD_RC=$?
run_capture "$LOG_DIR/$TS.swift_version.txt" swift --version; SWIFT_VERSION_RC=$?
run_capture "$LOG_DIR/$TS.xcodebuild_version.txt" xcodebuild -version; XCODEBUILD_VERSION_RC=$?
run_capture "$LOG_DIR/$TS.package_dump.json" swift package dump-package; DUMP_RC=$?
run_capture "$LOG_DIR/$TS.package_describe.txt" swift package describe; DESCRIBE_RC=$?
run_capture "$LOG_DIR/$TS.swift_build.log" swift build; BUILD_RC=$?
run_capture "$LOG_DIR/$TS.swift_test.log" swift test; TEST_RC=$?

cd "$REPO"

run_capture "$LOG_DIR/$TS.docker_version.txt" docker version; DOCKER_VERSION_RC=$?
run_capture "$LOG_DIR/$TS.docker_compose_version.txt" docker compose version; COMPOSE_VERSION_RC=$?
run_capture "$LOG_DIR/$TS.compose_config.log" docker compose -f "$COMPOSE_FILE" -p quantumai-stack config; COMPOSE_RC=$?
run_capture "$LOG_DIR/$TS.pip_version.txt" python3 -m pip --version; PIP_RC=$?

{
echo "ACTIVE_DEV=$ACTIVE_DEV"
echo "XCRUN_SWIFT_RC=$XCRUN_SWIFT_RC"
echo "XCRUN_XCODEBUILD_RC=$XCRUN_XCODEBUILD_RC"
echo "SWIFT_VERSION_RC=$SWIFT_VERSION_RC"
echo "XCODEBUILD_VERSION_RC=$XCODEBUILD_VERSION_RC"
echo "DUMP_RC=$DUMP_RC"
echo "DESCRIBE_RC=$DESCRIBE_RC"
echo "BUILD_RC=$BUILD_RC"
echo "TEST_RC=$TEST_RC"
echo "DOCKER_VERSION_RC=$DOCKER_VERSION_RC"
echo "COMPOSE_VERSION_RC=$COMPOSE_VERSION_RC"
echo "COMPOSE_RC=$COMPOSE_RC"
echo "PIP_RC=$PIP_RC"
echo
echo "XCRUN_SWIFT=$(cat "$LOG_DIR/$TS.xcrun_swift.txt" 2>/dev/null || true)"
echo "XCRUN_XCODEBUILD=$(cat "$LOG_DIR/$TS.xcrun_xcodebuild.txt" 2>/dev/null || true)"
echo
echo "SWIFT_VERSION:"
cat "$LOG_DIR/$TS.swift_version.txt" 2>/dev/null || true
echo
echo "XCODEBUILD_VERSION:"
cat "$LOG_DIR/$TS.xcodebuild_version.txt" 2>/dev/null || true
echo
echo "DOCKER_VERSION:"
cat "$LOG_DIR/$TS.docker_version.txt" 2>/dev/null || true
echo
echo "DOCKER_COMPOSE_VERSION:"
cat "$LOG_DIR/$TS.docker_compose_version.txt" 2>/dev/null || true
echo
echo "PACKAGE_TARGET_CHECK:"
sed -n '1,220p' "$IOS_ROOT/Package.swift" 2>/dev/null || true
echo
echo "STORAGE_QUEUE_CHECK:"
grep -n 'queueForBroadcast\|outbox\|removeFromOutbox' "$APP_ROOT/StorageKit/StorageService.swift" 2>/dev/null || true
echo
echo "WALLET_QUEUE_CALL_CHECK:"
grep -n 'queueForBroadcast\|performSecureTransaction' "$APP_ROOT/AppShell/WalletView.swift" 2>/dev/null || true
echo
echo "TEST_IMPORT_CHECK:"
grep -n '^import ' "$TEST_ROOT"/*.swift 2>/dev/null || true
echo
echo "SWIFT_BUILD_LAST_120:"
tail -n 120 "$LOG_DIR/$TS.swift_build.log" 2>/dev/null || true
echo
echo "SWIFT_TEST_LAST_120:"
tail -n 120 "$LOG_DIR/$TS.swift_test.log" 2>/dev/null || true
echo
echo "COMPOSE_CONFIG_LAST_80:"
tail -n 80 "$LOG_DIR/$TS.compose_config.log" 2>/dev/null || true
echo
echo "SUMMARY:"
[ "$BUILD_RC" -eq 0 ] && echo "SWIFT_BUILD_OK" || echo "SWIFT_BUILD_FAIL"
[ "$TEST_RC" -eq 0 ] && echo "SWIFT_TEST_OK" || echo "SWIFT_TEST_FAIL"
[ "$COMPOSE_RC" -eq 0 ] && echo "COMPOSE_OK" || echo "COMPOSE_FAIL"
echo
echo "REPORT_DIR=$LOG_DIR"
echo "FINAL_REPORT=$FINAL_REPORT"
} | tee "$FINAL_REPORT"

[ "$BUILD_RC" -eq 0 ] && [ "$TEST_RC" -eq 0 ] && [ "$COMPOSE_RC" -eq 0 ]
