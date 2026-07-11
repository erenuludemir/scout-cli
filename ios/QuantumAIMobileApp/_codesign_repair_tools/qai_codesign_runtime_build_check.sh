#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

PROJECT_DIR="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ios/QuantumAIMobileApp"
XCODEPROJ_PATH="$PROJECT_DIR/QuantumAIMobileApp.xcodeproj"
SCHEME="QuantumAIMobileApp"
OUT_DIR="$PROJECT_DIR/_codesign_repair_tools/runtime_build_check_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT_DIR"

xcodebuild -project "$XCODEPROJ_PATH" -scheme "$SCHEME" -configuration Debug -destination 'generic/platform=iOS Simulator' build > "$OUT_DIR/sim_build.log" 2>&1 || true
grep -nE '\*\* BUILD SUCCEEDED \*\*|\*\* BUILD FAILED \*\*|error:|warning:' "$OUT_DIR/sim_build.log" > "$OUT_DIR/sim_build.filtered.txt" || true

printf 'OUT_DIR=%s\n' "$OUT_DIR"
printf 'FILTERED=%s\n' "$OUT_DIR/sim_build.filtered.txt"
