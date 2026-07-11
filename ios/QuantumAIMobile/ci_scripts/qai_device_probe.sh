#!/usr/bin/env bash
set -euo pipefail

DEVICE_UDID="${1:-00008120-001644AC3A10C01E}"
BUNDLE_ID="${2:-com.erenuludemir.quantumaimobile}"
DERIVED_DATA_DIR="${HOME}/Library/Developer/Xcode/DerivedData/QuantumAIMobileApp-hkwamvbbytauwdfudesgsrwqvxsu/Logs/Launch"

echo "== Physical iOS devices =="
xcrun xcdevice list | jq -r '
  map(select(.simulator == false and .platform == "com.apple.platform.iphoneos"))[]
  | "\(.name)\t\(.identifier)\tavailable=\(.available)\tinterface=\(.interface // "-")\terror=\(.error.description // "-")"
'

echo
echo "== App installed =="
xcrun devicectl device info apps --device "${DEVICE_UDID}" --bundle-id "${BUNDLE_ID}" || true

echo
echo "== Process state =="
xcrun devicectl device info processes \
  --device "${DEVICE_UDID}" \
  --filter 'executableName CONTAINS[c] "QuantumAIMobileApp" OR executableName CONTAINS[c] "QuantumAI"' || true

LATEST_XCRESULT="$(
  find "${DERIVED_DATA_DIR}" -maxdepth 1 -type d -name 'Run-QuantumAIMobileApp-*.xcresult' -print |
    sort |
    tail -n 1 || true
)"
if [[ -z "${LATEST_XCRESULT}" ]]; then
  echo
  echo "No Launch xcresult found under ${DERIVED_DATA_DIR}"
  exit 0
fi

echo
echo "== Latest launch xcresult =="
echo "${LATEST_XCRESULT}"
xcrun xcresulttool get object --legacy --path "${LATEST_XCRESULT}" --format json | jq '
  .actions._values[]
  | {
      runDestination: .runDestination.displayName._value,
      startedTime: .startedTime._value,
      endedTime: .endedTime._value,
      status: .actionResult.status._value,
      consoleRef: .actionResult.consoleLogRef.id._value
    }
'

CONSOLE_REF="$(
  xcrun xcresulttool get object --legacy --path "${LATEST_XCRESULT}" --format json |
    jq -r '.actions._values[0].actionResult.consoleLogRef.id._value // empty'
)"

if [[ -z "${CONSOLE_REF}" ]]; then
  echo
  echo "No console log attached to latest launch xcresult."
  exit 0
fi

echo
echo "== Console messages =="
xcrun xcresulttool get object --legacy --path "${LATEST_XCRESULT}" --id "${CONSOLE_REF}" --format json | jq -r '
  .items._values[]?
  | select(.content._value? != null)
  | "\(.kind._value // "log"): \(.content._value)"
'
