#!/bin/zsh
### QAI_PREVENTIVE_PREFLIGHT_START ###
QAI_LANE_SELF_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
QAI_LANE_ROOT_DEFAULT="$(CDPATH='' cd -- "$QAI_LANE_SELF_DIR/.." && pwd -P)"
QAI_LANE_ROOT="${QAI_LANE_ROOT:-$QAI_LANE_ROOT_DEFAULT}"
QAI_RUNTIME_COMPOSE_DEFAULT="$QAI_LANE_ROOT/backend/qai_runtime/compose.dev.yml"
QAI_RUNTIME_COMPOSE="${QAI_RUNTIME_COMPOSE:-$QAI_RUNTIME_COMPOSE_DEFAULT}"
QAI_DOCKER_CONTEXT_CANDIDATES="${QAI_DOCKER_CONTEXT_CANDIDATES:-default colima colima-qai colima-mcai-colima mcai-colima}"
QAI_DOCKER_BIN="${QAI_DOCKER_BIN:-docker}"
QAI_COLIMA_BIN="${QAI_COLIMA_BIN:-colima}"
QAI_CONFLICT_CONTAINER_NAMES="${QAI_CONFLICT_CONTAINER_NAMES:-qai-redpanda qai-redis qai-postgres qai-runtime-api qai-runtime-worker qai-prometheus qai-grafana}"

qai_log() {
  printf '[qai-faz13] %s
' "$*"
}

qai_have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

qai_detect_runtime_compose() {
  if [ -f "$QAI_RUNTIME_COMPOSE" ]; then
    return 0
  fi

  local candidate
  for candidate in \
    "$QAI_LANE_ROOT/backend/qai_runtime/compose.dev.yml" \
    "$QAI_LANE_ROOT/backend/qai_runtime/docker-compose.yml" \
    "$QAI_LANE_ROOT/docker-compose.yml" \
    "$QAI_LANE_ROOT/compose.yml"
  do
    if [ -f "$candidate" ]; then
      QAI_RUNTIME_COMPOSE="$candidate"
      export QAI_RUNTIME_COMPOSE
      qai_log "runtime compose: $QAI_RUNTIME_COMPOSE"
      return 0
    fi
  done

  qai_log "runtime compose bulunamadi"
  return 1
}

qai_docker_ping() {
  "$QAI_DOCKER_BIN" info >/dev/null 2>&1
}

qai_print_docker_state() {
  (
    set +e
    qai_log "docker context ls"
    "$QAI_DOCKER_BIN" context ls 2>/dev/null || true
    qai_log "docker context show"
    "$QAI_DOCKER_BIN" context show 2>/dev/null || true
    qai_log "docker host env"
    printf 'DOCKER_HOST=%s
' "${DOCKER_HOST:-}"
    printf 'DOCKER_CONTEXT=%s
' "${DOCKER_CONTEXT:-}"
  ) >&2
}

qai_try_context_use() {
  local ctx="$1"
  "$QAI_DOCKER_BIN" context inspect "$ctx" >/dev/null 2>&1 || return 1
  "$QAI_DOCKER_BIN" context use "$ctx" >/dev/null 2>&1 || return 1
  qai_docker_ping
}

qai_fix_docker_endpoint() {
  if qai_docker_ping; then
    return 0
  fi

  qai_log "docker daemon erisimi yok, context toparlaniyor"
  qai_print_docker_state

  unset DOCKER_HOST || true
  unset DOCKER_CONTEXT || true

  local ctx
  for ctx in $QAI_DOCKER_CONTEXT_CANDIDATES; do
    if qai_try_context_use "$ctx"; then
      qai_log "aktif docker context: $ctx"
      return 0
    fi
  done

  if qai_have_cmd "$QAI_COLIMA_BIN"; then
    local profile
    for profile in mcai-colima default; do
      "$QAI_COLIMA_BIN" start -p "$profile" >/dev/null 2>&1 || true
    done

    for ctx in $QAI_DOCKER_CONTEXT_CANDIDATES; do
      if qai_try_context_use "$ctx"; then
        qai_log "aktif docker context: $ctx"
        return 0
      fi
    done
  fi

  return 1
}

qai_cleanup_named_container() {
  local name="$1"
  if "$QAI_DOCKER_BIN" ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
    qai_log "eski container bulundu: $name"
    "$QAI_DOCKER_BIN" logs --tail=120 "$name" >/dev/null 2>&1 || true
    "$QAI_DOCKER_BIN" rm -f "$name" >/dev/null 2>&1 || true
    sleep 1
    if "$QAI_DOCKER_BIN" ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
      qai_log "container hala mevcut: $name"
      return 1
    fi
    qai_log "container temizlendi: $name"
  fi
  return 0
}

qai_cleanup_conflicts() {
  qai_fix_docker_endpoint || return 0
  local name
  for name in $QAI_CONFLICT_CONTAINER_NAMES; do
    qai_cleanup_named_container "$name" || true
  done
  return 0
}

qai_dc() {
  qai_fix_docker_endpoint || {
    qai_log "docker daemon hazir degil"
    return 1
  }

  if [ -f "$QAI_RUNTIME_COMPOSE" ]; then
    "$QAI_DOCKER_BIN" compose -f "$QAI_RUNTIME_COMPOSE" "$@"
  else
    "$QAI_DOCKER_BIN" compose "$@"
  fi
}

qai_preflight_lane() {
  qai_log "preflight basladi"
  qai_detect_runtime_compose || true
  qai_cleanup_conflicts || true
  qai_log "preflight tamamlandi"
}
### QAI_PREVENTIVE_PREFLIGHT_END ###


set -euo pipefail
qai_preflight_lane

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE_ID="${1:-00008120-001644AC3A10C01E}"
STAMP="${2:-$(date +%Y%m%d_%H%M%S)}"
RUN_UI_TESTS="${QAI_RUN_UI_TESTS:-0}"
DEPLOY_WEB="${QAI_DEPLOY_WEB:-1}"
PAGES_PROJECT="${QAI_PAGES_PROJECT:-quantumaimobile-win}"

LOG_ROOT="$ROOT/_logs/faz13/$STAMP"
BACKUP_ROOT="$ROOT/_backups/faz13/$STAMP"
HOST_DERIVED="$ROOT/ios/QuantumAIMobile/.DerivedData_Faz13_Host"
APP_DERIVED="$ROOT/ios/QuantumAIMobileApp/.DerivedData_Faz13_App"
HOST_APP="$HOST_DERIVED/Build/Products/Debug-iphoneos/QuantumAIMobileHost.app"
MAIN_APP="$APP_DERIVED/Build/Products/Debug-iphoneos/QuantumAIMobileApp.app"
ARCHIVE_PATH="$LOG_ROOT/exports/QuantumAIMobileApp_Faz13.xcarchive"
EXPORT_PATH="$LOG_ROOT/exports/QuantumAIMobileApp_Faz13_export"
EXPORT_OPTIONS="$ROOT/ios/QuantumAIMobileApp/build/Faz13DebugExportOptions.plist"
UITEST_RESULT="$LOG_ROOT/exports/QuantumAIMobileAppUITests.xcresult"
UITEST_LOG="$LOG_ROOT/reports/ui_tests.log"
WEB_ROOT="$ROOT/web/quantumaimobile.win"
WEB_DEPLOY_LOG="$LOG_ROOT/reports/web_deploy.log"
WEB_DEPLOYMENTS_LOG="$LOG_ROOT/reports/web_deployments.log"
LIVE_CHECKLIST="$LOG_ROOT/reports/live_spot_operator_checklist.md"

mkdir -p "$LOG_ROOT/raw" "$LOG_ROOT/reports" "$LOG_ROOT/screens" "$LOG_ROOT/exports" "$BACKUP_ROOT"

cp \
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/AppShell/TrainingJourneyView.swift" \
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/AppShell/MarketBridgeView.swift" \
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/AppShell/TrainingDemoCenterView.swift" \
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/CoreKit/TrainingBundleResource.swift" \
  "$BACKUP_ROOT/" 2>/dev/null || true

"$ROOT/backend/qai_runtime/boot_local_stack.sh"
curl -fsS http://127.0.0.1:8787/ready > "$LOG_ROOT/reports/runtime_ready.json"
curl -fsS http://MacBook-Air.local:8787/health > "$LOG_ROOT/reports/runtime_device_health.json"

xcodebuild -project "$ROOT/ios/QuantumAIMobile/QuantumAIMobileHost.xcodeproj" \
  -scheme QuantumAIMobileHost \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$HOST_DERIVED" \
  build >/dev/null

xcodebuild -project "$ROOT/ios/QuantumAIMobileApp/QuantumAIMobileApp.xcodeproj" \
  -scheme QuantumAIMobileApp \
  -configuration Debug \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$APP_DERIVED" \
  build >/dev/null

xcrun devicectl device install app --device "$DEVICE_ID" "$HOST_APP" >/dev/null
xcrun devicectl device install app --device "$DEVICE_ID" "$MAIN_APP" >/dev/null
xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing com.erenuludemir.quantumaimobile.host >/dev/null
xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing com.erenuludemir.quantumaimobile >/dev/null

xcrun xctrace record --template 'Leaks' --device "$DEVICE_ID" --attach QuantumAIMobileHost \
  --output "$LOG_ROOT/raw/QuantumAIMobileHost_Physical_Leaks.trace" \
  --time-limit 15s --no-prompt >/dev/null

xcrun xctrace record --template 'Leaks' --device "$DEVICE_ID" --attach QuantumAIMobileApp \
  --output "$LOG_ROOT/raw/QuantumAIMobileApp_Physical_Leaks.trace" \
  --time-limit 15s --no-prompt >/dev/null

xcrun xctrace export --input "$LOG_ROOT/raw/QuantumAIMobileHost_Physical_Leaks.trace" --toc > "$LOG_ROOT/exports/host_trace_toc.xml"
xcrun xctrace export --input "$LOG_ROOT/raw/QuantumAIMobileApp_Physical_Leaks.trace" --toc > "$LOG_ROOT/exports/app_trace_toc.xml"

if [[ "$RUN_UI_TESTS" == "1" ]]; then
  xcodebuild -project "$ROOT/ios/QuantumAIMobileApp/QuantumAIMobileApp.xcodeproj" \
    -scheme QuantumAIMobileApp \
    -configuration Debug \
    -destination "id=$DEVICE_ID" \
    -derivedDataPath "$APP_DERIVED" \
    build-for-testing >/dev/null

  xcodebuild -project "$ROOT/ios/QuantumAIMobileApp/QuantumAIMobileApp.xcodeproj" \
    -scheme QuantumAIMobileApp \
    -configuration Debug \
    -destination "id=$DEVICE_ID" \
    -derivedDataPath "$APP_DERIVED" \
    -parallel-testing-enabled NO \
    -only-testing:QuantumAIMobileAppUITests/testBottomNavigationPrimaryTabsFlow \
    -only-testing:QuantumAIMobileAppUITests/testPanelOperationsMenuOpensMarketBridge \
    -only-testing:QuantumAIMobileAppUITests/testSettingsLinkOpensMarketBridge \
    -resultBundlePath "$UITEST_RESULT" \
    test-without-building > "$UITEST_LOG"
fi

xcrun devicectl device info appIcon --device "$DEVICE_ID" --app-bundle-id com.erenuludemir.quantumaimobile \
  --destination "$LOG_ROOT/screens/QuantumAI_device_icon.png" >/dev/null
xcrun devicectl device info appIcon --device "$DEVICE_ID" --app-bundle-id com.erenuludemir.quantumaimobile.host \
  --destination "$LOG_ROOT/screens/QuantumAI_Host_device_icon.png" >/dev/null
xcrun devicectl device info displays --device "$DEVICE_ID" --json-output "$LOG_ROOT/screens/device_displays.json" >/dev/null

xcodebuild -project "$ROOT/ios/QuantumAIMobileApp/QuantumAIMobileApp.xcodeproj" \
  -scheme QuantumAIMobileApp \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  archive >/dev/null

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates >/dev/null

if [[ "$DEPLOY_WEB" == "1" && -d "$WEB_ROOT" ]]; then
  (
    cd "$WEB_ROOT"
    ./deploy.sh
  ) >"$WEB_DEPLOY_LOG" 2>&1 || true

  (
    cd "$WEB_ROOT"
    npx wrangler pages deployment list --project-name "$PAGES_PROJECT"
  ) >"$WEB_DEPLOYMENTS_LOG" 2>&1 || true
fi

cat > "$LIVE_CHECKLIST" <<EOF
# QuantumAI Live Spot Operator Checklist

- Device lane: $DEVICE_ID
- Runtime ready report: $LOG_ROOT/reports/runtime_ready.json
- Runtime health report: $LOG_ROOT/reports/runtime_device_health.json
- App export: $EXPORT_PATH/QuantumAIMobileApp.ipa
- UI tests enabled: $RUN_UI_TESTS
- Web deploy enabled: $DEPLOY_WEB

## Manual pre-trade checks

1. Open QuantumAI on the physical device.
2. Go to Settings > Referans Araçları.
3. Tap "Canlı Spot Hazırla" and confirm the dialog.
4. Verify these states:
   - Paper Trading = off
   - Live Adapters = on
   - Telemetry = on
   - CoinMarketCap Bridge = on
5. Confirm the micro test amount is between 3 USD and 5 USD.
6. Open "Binance Doğrulama Panelini Aç", complete the provider-return verification, then return to the app.
7. Check that Wallet status shows the live lane as ready.
8. Perform the real trade manually. This script does not place an order.
9. After the manual trade, return to QuantumAI and verify wallet summary, feed state, and runtime pulse.
EOF

{
  echo "faz13_stamp=$STAMP"
  echo "device_id=$DEVICE_ID"
  echo "host_app=$HOST_APP"
  echo "main_app=$MAIN_APP"
  echo "archive=$ARCHIVE_PATH"
  echo "export=$EXPORT_PATH/QuantumAIMobileApp.ipa"
  echo "ui_tests_enabled=$RUN_UI_TESTS"
  echo "ui_test_result=$UITEST_RESULT"
  echo "web_deploy_enabled=$DEPLOY_WEB"
  echo "web_deploy_log=$WEB_DEPLOY_LOG"
  echo "web_deployments_log=$WEB_DEPLOYMENTS_LOG"
  echo "live_checklist=$LIVE_CHECKLIST"
} > "$LOG_ROOT/reports/physical_lane_summary.env"

echo "Faz 13 physical lane complete: $LOG_ROOT"
