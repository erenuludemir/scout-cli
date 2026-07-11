#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
OUT="$ROOT/_reports/repair_runbook/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"

PKG="$ROOT/ios/QuantumAIMobile/Package.swift"
HOST_PBX="$ROOT/ios/QuantumAIMobileHost.xcodeproj/project.pbxproj"

{
  echo "ROOT=$ROOT"
  echo "OUT=$OUT"
  echo "DATE=$(date '+%Y-%m-%d %H:%M:%S')"
  echo "PWD=$(pwd)"
} > "$OUT/00_manifest.txt"

echo "[1/12] suspicious file inventory"
find "$ROOT" -type f \
  \( -name "*.bak*" -o -name "*.orig*" -o -name "*.tmp*" -o -name "*.disabled*" -o -name "*.legacy*" -o -name "*.sample*" \) \
  | sed "s#^$ROOT/##" | sort > "$OUT/01_suspicious_files.txt" || true

echo "[2/12] package manifest snapshot"
if [ -f "$PKG" ]; then
  {
    echo "=== Package.swift path ==="
    echo "$PKG"
    echo
    echo "=== target/exclude/sources/resources lines ==="
    grep -nE 'target\(|testTarget\(|exclude:|sources:|resources:|path:' "$PKG" || true
    echo
    echo "=== suspicious tokens in Package.swift ==="
    grep -nE '\.bak|\.orig|\.tmp|\.disabled|\.legacy|\.sample|PerformanceChart|SyncClient|RootView' "$PKG" || true
  } > "$OUT/02_package_scope.txt"
else
  echo "MISSING: $PKG" > "$OUT/02_package_scope.txt"
fi

echo "[3/12] xcode project suspicious references"
: > "$OUT/03_xcodeproj_refs.txt"
find "$ROOT/ios" -type f -name project.pbxproj | while IFS= read -r pbx; do
  {
    echo "=== $pbx ==="
    grep -nE '\.bak|\.orig|\.tmp|\.disabled|\.legacy|\.sample|RootView|SyncClient|PerformanceChart|SummaryStatCard|TerminalStatCard|LoginView|BinanceAdapter' "$pbx" || true
    echo
  } >> "$OUT/03_xcodeproj_refs.txt"
done

echo "[4/12] compile/resource phase hints"
: > "$OUT/04_build_phase_hints.txt"
find "$ROOT/ios" -type f -name project.pbxproj | while IFS= read -r pbx; do
  {
    echo "=== $pbx ==="
    grep -nE 'PBXSourcesBuildPhase|PBXResourcesBuildPhase|Compile Sources|Copy Bundle Resources' "$pbx" || true
    echo
  } >> "$OUT/04_build_phase_hints.txt"
done

echo "[5/12] duplicate type/function ownership scan"
TARGET_DIR="$ROOT/ios/QuantumAIMobile/QuantumAIMobile"
{
  echo "=== RawTransaction definitions ==="
  grep -RInE '\b(struct|class|enum|typealias)\s+RawTransaction\b|\bextension\s+RawTransaction\b' "$TARGET_DIR" --include='*.swift' || true
  echo
  echo "=== signTRON definitions ==="
  grep -RInE '\bfunc\s+signTRON\s*\(' "$TARGET_DIR" --include='*.swift' || true
  echo
  echo "=== init(chainId:nonce:to:value:data:) hits ==="
  grep -RInE 'init\s*\(\s*chainId:\s*.*nonce:\s*.*to:\s*.*value:\s*.*data:' "$TARGET_DIR" --include='*.swift' || true
} > "$OUT/05_wallet_duplicate_scan.txt"

echo "[6/12] canonical owner scan"
{
  for sym in watchlist outbox appendAudit append flushOutbox queueForBroadcast BinanceAdapter LoginView SummaryStatCard TerminalStatCard PerformanceChart sampleData; do
    echo "=== SYMBOL: $sym ==="
    grep -RInE "\\b${sym}\\b" "$TARGET_DIR" --include='*.swift' || true
    echo
  done
} > "$OUT/06_owner_surface_scan.txt"

echo "[7/12] targeted file snapshots"
FILES=(
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/WalletKit/TransactionSigner.swift"
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/WalletKit/WalletService.swift"
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/AppShell/WalletView.swift"
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/AppShell/AppEnvironment.swift"
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/StorageKit/StorageService.swift"
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/StorageKit/AuditService.swift"
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/SettingsKit/SyncClient.swift"
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/SyncKit/RemoteMonitor.swift"
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/ObservabilityKit/HealthPanelModel.swift"
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/BotKit/BotService.swift"
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/BotKit/CopyTradeService.swift"
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/AppShell/LoginView.swift"
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/AppShell/BinanceMasterPanel.swift"
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/AppShell/DashboardView.swift"
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/MarketKit/MarketDataService.swift"
)
: > "$OUT/07_targeted_file_status.txt"
for f in "${FILES[@]}"; do
  if [ -f "$f" ]; then
    {
      echo "OK: $f"
      wc -l "$f"
    } >> "$OUT/07_targeted_file_status.txt"
  else
    echo "MISSING: $f" >> "$OUT/07_targeted_file_status.txt"
  fi
done

echo "[8/12] suspicious file references inside swift sources"
{
  grep -RInE '\.bak|\.orig|\.tmp|\.disabled|\.legacy|\.sample' "$TARGET_DIR" --include='*.swift' || true
} > "$OUT/08_swift_suspicious_refs.txt"

echo "[9/12] package/xcode dual-path syncclient hints"
{
  echo "=== Package.swift mentions ==="
  grep -nE 'SyncClient|SyncKit' "$PKG" || true
  echo
  echo "=== project.pbxproj mentions ==="
  find "$ROOT/ios" -type f -name project.pbxproj -print0 | xargs -0 grep -nE 'SyncClient|SyncKit' || true
} > "$OUT/09_syncclient_path_overlap.txt"

echo "[10/12] generic build commands"
cat > "$OUT/10_build_commands.sh" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"

xcodebuild \
  -project "$ROOT/ios/QuantumAIMobileApp/QuantumAIMobileApp.xcodeproj" \
  -scheme "QuantumAIMobileApp" \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

xcodebuild \
  -project "$ROOT/ios/QuantumAIMobileApp/QuantumAIMobileApp.xcodeproj" \
  -scheme "QuantumAIMobileApp" \
  -showBuildSettings > "$ROOT/_reports/repair_runbook/buildsettings.latest.txt"
SH
chmod +x "$OUT/10_build_commands.sh"

echo "[11/12] remediation summary"
{
  echo "1) 01_suspicious_files.txt içindeki backup/geçici dosyaları build kapsamı dışına al"
  echo "2) 02_package_scope.txt ile Package.swift exclude/sources/resources çizgisini sabitle"
  echo "3) 03_xcodeproj_refs.txt ve 04_build_phase_hints.txt ile target membership/build phase kirliliğini temizle"
  echo "4) 05_wallet_duplicate_scan.txt ile RawTransaction/signTRON duplicate owner'ı tekilleştir"
  echo "5) 06_owner_surface_scan.txt ile watchlist/outbox/appendAudit/flushOutbox/queueForBroadcast owner'larını sabitle"
  echo "6) 07_targeted_file_status.txt ile eksik dosya var mı kontrol et"
  echo "7) 10_build_commands.sh ile signing karışmadan generic code build al"
} > "$OUT/11_next_actions.txt"

echo "[12/12] final index"
{
  echo "REPORT_DIR=$OUT"
  ls -1 "$OUT"
} > "$OUT/12_index.txt"

printf '%s\n' "$OUT"
