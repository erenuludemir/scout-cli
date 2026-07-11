#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
APP_DIR="$ROOT/ios/QuantumAIMobileApp"
PKG_DIR="$ROOT/ios/QuantumAIMobile"
APP_XCODEPROJ="$APP_DIR/QuantumAIMobileApp.xcodeproj"
SPM_CACHE_DIR="$ROOT/_spm_cache_quantumaimobileapp_scope_fix"
OUT="$ROOT/_reports/repair_runbook/codebuild_after_scope_fix_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"

STRAY_MANIFEST="$APP_XCODEPROJ/Package.swift"
if [ -f "$STRAY_MANIFEST" ]; then
  TS="$(date +%Y%m%d_%H%M%S)"
  mv "$STRAY_MANIFEST" "$APP_XCODEPROJ/Package.swift.disabled.$TS"
fi

rm -rf "$APP_XCODEPROJ/.swiftpm" \
       "$APP_XCODEPROJ/project.xcworkspace/xcshareddata/swiftpm" \
       "$APP_XCODEPROJ/xcuserdata" \
       "$HOME/Library/Caches/org.swift.swiftpm" \
       "$HOME/Library/org.swift.swiftpm" \
       "$HOME/Library/Developer/Xcode/DerivedData/QuantumAIMobileApp-"* \
       "$HOME/Library/Developer/Xcode/DerivedData/QuantumAIMobile-"* \
       "$SPM_CACHE_DIR"
mkdir -p "$SPM_CACHE_DIR"

{
  echo "=== APP XCODEPROJ PACKAGE/MANIFEST FILES ==="
  find "$APP_XCODEPROJ" -type f | grep -E 'Package.swift|Package.resolved|workspace-state|swiftpm|manifest' || true
  echo
  echo "=== REAL PACKAGE RESOLVE ==="
  cd "$PKG_DIR"
  xcodebuild -resolvePackageDependencies
  echo
  echo "=== APP PROJECT RESOLVE ==="
  cd "$APP_DIR"
  xcodebuild \
    -project "$APP_XCODEPROJ" \
    -resolvePackageDependencies \
    -clonedSourcePackagesDirPath "$SPM_CACHE_DIR"
  echo
  echo "=== GENERIC IOS SIMULATOR BUILD ==="
  xcodebuild \
    -project "$APP_XCODEPROJ" \
    -scheme "QuantumAIMobileApp" \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -clonedSourcePackagesDirPath "$SPM_CACHE_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    build
} > "$OUT/build.log" 2>&1 || true

python3 - <<'PY' "$OUT/build.log" "$OUT/summary_first_errors.txt"
from pathlib import Path
import sys

log_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
lines = log_path.read_text(errors="ignore").splitlines()
picked = []

for idx, line in enumerate(lines, start=1):
    lower = line.lower()
    if (
        " error:" in lower or lower.startswith("error:") or
        " warning:" in lower or " note:" in lower or
        "swiftcompile normal" in lower or
        "swiftemitmodule" in lower or
        "the following build commands failed:" in lower or
        "** build failed **" in lower or
        "** build succeeded **" in lower
    ):
        picked.append(f"{idx}:{line}")

seen = set()
ordered = []
for item in picked:
    if item not in seen:
        seen.add(item)
        ordered.append(item)

out_path.write_text(("\n".join(ordered[:500]) + "\n") if ordered else "", encoding="utf-8")
PY

grep -nEi 'error:|fatal error:|warning:|note:|The following build commands failed:|\*\* BUILD FAILED \*\*|\*\* BUILD SUCCEEDED \*\*|could not build module|no such module|cannot find|invalid redeclaration|ambiguous use|type .* has no member|value of type .* has no member|use of unresolved identifier|missing argument|extra argument|cannot convert value|initializer .* is ambiguous|SwiftCompile normal|SwiftEmitModule|PerformanceChart|BinanceAdapter|RawTransaction|signTRON|watchlist|outbox|appendAudit|flushOutbox|queueForBroadcast|Invalid Exclude' \
  "$OUT/build.log" > "$OUT/key_matches.log" || true

printf '%s\n' "$OUT"
