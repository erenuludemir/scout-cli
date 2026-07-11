#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IOS_PACKAGE_DIR="$ROOT_DIR/ios/QuantumAIMobile"
IOS_APP_DIR="$ROOT_DIR/ios/QuantumAIMobileApp"
HOST_PROJECT="$IOS_PACKAGE_DIR/QuantumAIMobileHost.xcodeproj"
APP_PROJECT="$IOS_APP_DIR/QuantumAIMobileApp.xcodeproj"
APP_SCHEME="${QAI_IOS_SCHEME:-QuantumAIMobileApp}"
APP_BUNDLE_ID="${QAI_IOS_BUNDLE_ID:-com.erenuludemir.quantumaimobile}"
HOST_SCHEME="${QAI_IOS_HOST_SCHEME:-QuantumAIMobileHost}"
HOST_BUNDLE_ID="${QAI_IOS_HOST_BUNDLE_ID:-com.erenuludemir.quantumaimobile.host}"
APP_DERIVED_DATA="${QAI_IOS_DERIVED_DATA:-$IOS_APP_DIR/build/DerivedData}"
HOST_DERIVED_DATA="${QAI_IOS_HOST_DERIVED_DATA:-$IOS_PACKAGE_DIR/build/DerivedDataHost}"
ARCHIVE_PATH="${QAI_IOS_ARCHIVE_PATH:-$IOS_APP_DIR/build/QuantumAIMobileApp.xcarchive}"
SIM_DEVICE_NAME="${SIM_DEVICE_NAME:-${QAI_IOS_SIM_DEVICE_NAME:-}}"
LOG_ROOT="${QAI_IOS_AUTOPILOT_LOG_ROOT:-$ROOT_DIR/_logs/app_autopilot}"
RUN_ID="$(date +%Y%m%d_%H%M%S)_$$"
RUN_DIR="$LOG_ROOT/$RUN_ID"
SUMMARY_FILE="$RUN_DIR/summary.env"
MODE="${1:-all}"
TEMP_SIM_CREATED=0
DEVICE_UDID=""

mkdir -p "$RUN_DIR"
: > "$SUMMARY_FILE"

cleanup() {
  if [ "${TEMP_SIM_CREATED:-0}" -eq 1 ] && [ -n "${DEVICE_UDID:-}" ]; then
    xcrun simctl shutdown "$DEVICE_UDID" >/dev/null 2>&1 || true
    xcrun simctl delete "$DEVICE_UDID" >/dev/null 2>&1 || true
  fi
}

trap cleanup EXIT

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

record() {
  printf '%s=%s\n' "$1" "$2" >> "$SUMMARY_FILE"
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required tool: $1" >&2
    exit 1
  }
}

run_logged() {
  local step="$1"
  shift
  local logfile="$RUN_DIR/${step}.log"
  log "STEP ${step}"
  if "$@" >"$logfile" 2>&1; then
    record "${step}_STATUS" "OK"
    record "${step}_LOG" "$logfile"
  else
    record "${step}_STATUS" "FAIL"
    record "${step}_LOG" "$logfile"
    cat "$logfile" >&2
    exit 1
  fi
}

doctor() {
  need xcodegen
  need swift
  need xcodebuild
  need xcrun
  need python3

  test -d "$IOS_PACKAGE_DIR"
  test -d "$IOS_APP_DIR"
  test -f "$IOS_PACKAGE_DIR/Package.swift"
  test -f "$IOS_PACKAGE_DIR/project.yml"
  test -f "$IOS_APP_DIR/project.yml"

  {
    echo "ROOT_DIR=$ROOT_DIR"
    echo "IOS_PACKAGE_DIR=$IOS_PACKAGE_DIR"
    echo "IOS_APP_DIR=$IOS_APP_DIR"
    echo "APP_SCHEME=$APP_SCHEME"
    echo "APP_BUNDLE_ID=$APP_BUNDLE_ID"
    echo "HOST_SCHEME=$HOST_SCHEME"
    echo "HOST_BUNDLE_ID=$HOST_BUNDLE_ID"
    echo "SWIFT_VERSION=$(swift --version | head -n1)"
    echo "XCODEGEN_VERSION=$(xcodegen --version | head -n1)"
    echo "XCODEBUILD_VERSION=$(xcodebuild -version | tr '\n' ' ' | sed 's/  */ /g')"
    echo "XCODE_SELECT=$(xcode-select -p)"
  } >"$RUN_DIR/doctor.log" 2>&1

  record "doctor_STATUS" "OK"
  record "doctor_LOG" "$RUN_DIR/doctor.log"
}

generate_project() {
  run_logged generate_project \
    env ROOT_DIR="$ROOT_DIR" IOS_APP_DIR="$IOS_APP_DIR" IOS_PACKAGE_DIR="$IOS_PACKAGE_DIR" bash -lc '
      cd "$IOS_PACKAGE_DIR"
      xcodegen generate
      cd "$IOS_APP_DIR"
      xcodegen generate
    '
}

swift_tests() {
  run_logged swift_tests \
    env IOS_PACKAGE_DIR="$IOS_PACKAGE_DIR" bash -lc '
      cd "$IOS_PACKAGE_DIR"
      swift test
    '
}

build_app_simulator() {
  select_simulator_udid
  run_logged build_app_simulator \
    env IOS_APP_DIR="$IOS_APP_DIR" APP_SCHEME="$APP_SCHEME" APP_DERIVED_DATA="$APP_DERIVED_DATA" DEVICE_UDID="$DEVICE_UDID" bash -lc '
      cd "$IOS_APP_DIR"
      xcodebuild \
        -project "QuantumAIMobileApp.xcodeproj" \
        -scheme "$APP_SCHEME" \
        -destination "id=$DEVICE_UDID" \
        -derivedDataPath "$APP_DERIVED_DATA" \
        build
    '
}

build_host_simulator() {
  select_simulator_udid
  run_logged build_host_simulator \
    env IOS_PACKAGE_DIR="$IOS_PACKAGE_DIR" HOST_SCHEME="$HOST_SCHEME" HOST_DERIVED_DATA="$HOST_DERIVED_DATA" DEVICE_UDID="$DEVICE_UDID" bash -lc '
      cd "$IOS_PACKAGE_DIR"
      xcodebuild \
        -project "QuantumAIMobileHost.xcodeproj" \
        -scheme "$HOST_SCHEME" \
        -destination "id=$DEVICE_UDID" \
        -derivedDataPath "$HOST_DERIVED_DATA" \
        build
    '
}

rest_probe() {
  run_logged rest_probe \
    bash -lc 'python3 - <<'"'"'PY'"'"'
import json
import urllib.request

with urllib.request.urlopen("https://api.binance.com/api/v3/ticker/24hr?symbol=BTCUSDT", timeout=15) as response:
    payload = json.load(response)

price = float(payload["lastPrice"])
volume = float(payload["volume"])
print(f"BTCUSDT={price:.2f} VOLUME={volume:.4f}")
PY'
}

select_simulator_udid() {
  if [ -n "${DEVICE_UDID:-}" ]; then
    export DEVICE_UDID
    return 0
  fi

  if [ -z "$SIM_DEVICE_NAME" ]; then
    read -r DEVICE_TYPE_ID RUNTIME_ID < <(
      xcrun simctl list -j | python3 -c '
import json
import sys

data = json.load(sys.stdin)

runtimes = [
    runtime for runtime in data.get("runtimes", [])
    if runtime.get("isAvailable") and runtime.get("identifier", "").startswith("com.apple.CoreSimulator.SimRuntime.iOS")
]
runtimes.sort(key=lambda item: item.get("version", item.get("name", "")), reverse=True)

device_types = [item for item in data.get("devicetypes", []) if item.get("name", "").startswith("iPhone")]

preferred_names = ["iPhone 17 Pro", "iPhone 17", "iPhone 16 Pro", "iPhone 16"]
device_type = None
for preferred_name in preferred_names:
    device_type = next((item for item in device_types if item.get("name") == preferred_name), None)
    if device_type is not None:
        break
if device_type is None and device_types:
    device_type = device_types[0]

if not runtimes or device_type is None:
    raise SystemExit(1)

print(device_type["identifier"], runtimes[0]["identifier"])
'
    )

    [ -n "${DEVICE_TYPE_ID:-}" ] || {
      echo "No available iPhone device type found." >&2
      exit 1
    }
    [ -n "${RUNTIME_ID:-}" ] || {
      echo "No available iOS simulator runtime found." >&2
      exit 1
    }

    DEVICE_UDID="$(xcrun simctl create "QAI-Autopilot-$RUN_ID" "$DEVICE_TYPE_ID" "$RUNTIME_ID")"
    TEMP_SIM_CREATED=1
    record "SIMULATOR_KIND" "ephemeral"
    record "SIMULATOR_DEVICE_TYPE" "$DEVICE_TYPE_ID"
    record "SIMULATOR_RUNTIME" "$RUNTIME_ID"
    record "SIMULATOR_UDID" "$DEVICE_UDID"
    export DEVICE_UDID
    return 0
  fi

  DEVICE_UDID="$(
    env TARGET_DEVICE_NAME="$SIM_DEVICE_NAME" xcrun simctl list devices available -j | python3 -c '
import json
import os
import sys

target_name = os.environ.get("TARGET_DEVICE_NAME", "")
data = json.load(sys.stdin)
fallback = None

for runtime in sorted(data["devices"].keys(), reverse=True):
    for device in data["devices"][runtime]:
        if not device.get("isAvailable"):
            continue
        if fallback is None and str(device.get("name", "")).startswith("iPhone"):
            fallback = device
        if target_name and device.get("name") == target_name:
            print(device["udid"])
            raise SystemExit(0)

if fallback is not None:
    print(fallback["udid"])
    raise SystemExit(0)

raise SystemExit(1)
'
  )"
  [ -n "${DEVICE_UDID:-}" ] || {
    echo "No available iPhone simulator found." >&2
    exit 1
  }
  record "SIMULATOR_KIND" "existing"
  export DEVICE_UDID
  record "SIMULATOR_UDID" "$DEVICE_UDID"
}

smoke_install_and_launch() {
  select_simulator_udid
  run_logged smoke_boot \
    env DEVICE_UDID="$DEVICE_UDID" bash -lc '
      open -a Simulator --args -CurrentDeviceUDID "$DEVICE_UDID" >/dev/null 2>&1 || true
      xcrun simctl boot "$DEVICE_UDID" >/dev/null 2>&1 || true
      xcrun simctl bootstatus "$DEVICE_UDID" -b
    '

  if [ ! -d "$APP_DERIVED_DATA/Build/Products/Debug-iphonesimulator/$APP_SCHEME.app" ]; then
    build_app_simulator
  fi

  if [ ! -d "$HOST_DERIVED_DATA/Build/Products/Debug-iphonesimulator/$HOST_SCHEME.app" ]; then
    build_host_simulator
  fi

  run_logged smoke_install_launch_app \
    env DEVICE_UDID="$DEVICE_UDID" APP_BUNDLE_ID="$APP_BUNDLE_ID" APP_SCHEME="$APP_SCHEME" APP_DERIVED_DATA="$APP_DERIVED_DATA" RUN_DIR="$RUN_DIR" bash -lc '
      launch_bundle() {
        local device_udid="$1"
        local bundle_id="$2"
        local launch_log="$3"
        local launch_wait="${QAI_IOS_LAUNCH_COMMAND_WAIT:-3}"

        xcrun simctl launch --terminate-running-process "$device_udid" "$bundle_id" >"$launch_log" 2>&1 &
        local launch_pid=$!
        sleep "$launch_wait"

        if kill -0 "$launch_pid" >/dev/null 2>&1; then
          echo "simctl launch remained attached after ${launch_wait}s; detaching client and continuing." >>"$launch_log"
          kill "$launch_pid" >/dev/null 2>&1 || true
          wait "$launch_pid" || true
        else
          wait "$launch_pid"
        fi
      }

      APP_PATH="$APP_DERIVED_DATA/Build/Products/Debug-iphonesimulator/$APP_SCHEME.app"
      test -d "$APP_PATH"
      xcrun simctl install "$DEVICE_UDID" "$APP_PATH"
      launch_bundle "$DEVICE_UDID" "$APP_BUNDLE_ID" "$RUN_DIR/${APP_SCHEME}.launch.log"
      sleep "${QAI_IOS_LAUNCH_SETTLE_WAIT:-4}"
      xcrun simctl io "$DEVICE_UDID" screenshot "$RUN_DIR/${APP_SCHEME}.png" >/dev/null
    '
  record "APP_SCREENSHOT" "$RUN_DIR/${APP_SCHEME}.png"
  record "APP_LAUNCH_LOG" "$RUN_DIR/${APP_SCHEME}.launch.log"

  run_logged smoke_install_launch_host \
    env DEVICE_UDID="$DEVICE_UDID" HOST_BUNDLE_ID="$HOST_BUNDLE_ID" HOST_SCHEME="$HOST_SCHEME" HOST_DERIVED_DATA="$HOST_DERIVED_DATA" RUN_DIR="$RUN_DIR" bash -lc '
      launch_bundle() {
        local device_udid="$1"
        local bundle_id="$2"
        local launch_log="$3"
        local launch_wait="${QAI_IOS_LAUNCH_COMMAND_WAIT:-3}"

        xcrun simctl launch --terminate-running-process "$device_udid" "$bundle_id" >"$launch_log" 2>&1 &
        local launch_pid=$!
        sleep "$launch_wait"

        if kill -0 "$launch_pid" >/dev/null 2>&1; then
          echo "simctl launch remained attached after ${launch_wait}s; detaching client and continuing." >>"$launch_log"
          kill "$launch_pid" >/dev/null 2>&1 || true
          wait "$launch_pid" || true
        else
          wait "$launch_pid"
        fi
      }

      APP_PATH="$HOST_DERIVED_DATA/Build/Products/Debug-iphonesimulator/$HOST_SCHEME.app"
      test -d "$APP_PATH"
      xcrun simctl install "$DEVICE_UDID" "$APP_PATH"
      launch_bundle "$DEVICE_UDID" "$HOST_BUNDLE_ID" "$RUN_DIR/${HOST_SCHEME}.launch.log"
      sleep "${QAI_IOS_LAUNCH_SETTLE_WAIT:-4}"
      xcrun simctl io "$DEVICE_UDID" screenshot "$RUN_DIR/${HOST_SCHEME}.png" >/dev/null
    '
  record "HOST_SCREENSHOT" "$RUN_DIR/${HOST_SCHEME}.png"
  record "HOST_LAUNCH_LOG" "$RUN_DIR/${HOST_SCHEME}.launch.log"
}

archive_release() {
  run_logged archive_release \
    env IOS_APP_DIR="$IOS_APP_DIR" APP_SCHEME="$APP_SCHEME" ARCHIVE_PATH="$ARCHIVE_PATH" bash -lc '
      cd "$IOS_APP_DIR"
      xcodebuild \
        -project "QuantumAIMobileApp.xcodeproj" \
        -scheme "$APP_SCHEME" \
        -configuration Release \
        -destination "generic/platform=iOS" \
        -archivePath "$ARCHIVE_PATH" \
        archive
    '
  record "ARCHIVE_PATH" "$ARCHIVE_PATH"
}

system_health() {
  if [ ! -x "$ROOT_DIR/ops/qai_project_health.sh" ]; then
    echo "System health script missing: $ROOT_DIR/ops/qai_project_health.sh" >&2
    exit 1
  fi
  run_logged system_health "$ROOT_DIR/ops/qai_project_health.sh"
}

write_report() {
  {
    echo "MODE=$MODE"
    echo "RUN_DIR=$RUN_DIR"
    echo "ROOT_DIR=$ROOT_DIR"
    cat "$SUMMARY_FILE"
  } >"$RUN_DIR/report.txt"
  cat "$RUN_DIR/report.txt"
}

usage() {
  cat <<'EOF'
Usage: ops/qai_app_autopilot.sh [doctor|generate|test|build|smoke|preflight|system|all|full]

  doctor     Toolchain ve kanonik path kontrolü
  generate   XcodeGen ile app projesini üret
  test       Swift package testlerini çalıştır
  build      App + host için iOS Simulator build al
  smoke      REST probe + app/host simulator install + launch + screenshot
  preflight  Generate + test + app/host simulator build + release archive
  system     Docker/system health özetini çalıştır
  all        Generate + test + simulator build + smoke
  full       System health + all
EOF
}

case "$MODE" in
  doctor)
    doctor
    ;;
  generate)
    doctor
    generate_project
    ;;
  test)
    doctor
    generate_project
    swift_tests
    ;;
  build)
    doctor
    generate_project
    build_app_simulator
    build_host_simulator
    ;;
  smoke)
    doctor
    generate_project
    rest_probe
    smoke_install_and_launch
    ;;
  preflight)
    doctor
    generate_project
    swift_tests
    build_app_simulator
    build_host_simulator
    archive_release
    ;;
  system)
    system_health
    ;;
  all)
    doctor
    generate_project
    swift_tests
    build_app_simulator
    build_host_simulator
    rest_probe
    smoke_install_and_launch
    ;;
  full)
    system_health
    doctor
    generate_project
    swift_tests
    build_app_simulator
    build_host_simulator
    rest_probe
    smoke_install_and_launch
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

write_report
