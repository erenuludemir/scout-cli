#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

PROJECT_DIR="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ios/QuantumAIMobileApp"
PROJECT_FILE="$PROJECT_DIR/QuantumAIMobileApp.xcodeproj/project.pbxproj"
XCODEPROJ_PATH="$PROJECT_DIR/QuantumAIMobileApp.xcodeproj"
SCHEME="QuantumAIMobileApp"
APP_TARGET_NAME="QuantumAIMobileApp"
OUT_DIR="$PROJECT_DIR/_codesign_repair_tools/output"
TS="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="$OUT_DIR/run_$TS"
BACKUP_DIR="$RUN_DIR/backups"
REPORT_DIR="$RUN_DIR/reports"
LOG_DIR="$RUN_DIR/logs"
PATCH_DIR="$RUN_DIR/patches"
mkdir -p "$BACKUP_DIR" "$REPORT_DIR" "$LOG_DIR" "$PATCH_DIR"

log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_DIR/main.log"; }
fail(){ log "HATA:$*"; exit 1; }

[ -d "$PROJECT_DIR" ] || fail "PROJECT_DIR_YOK:$PROJECT_DIR"
[ -f "$PROJECT_FILE" ] || fail "PROJECT_FILE_YOK:$PROJECT_FILE"
[ -d "$XCODEPROJ_PATH" ] || fail "XCODEPROJ_YOK:$XCODEPROJ_PATH"
command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild_yok"
command -v plutil >/dev/null 2>&1 || fail "plutil_yok"
command -v security >/dev/null 2>&1 || fail "security_yok"
command -v python3 >/dev/null 2>&1 || fail "python3_yok"

log "BASLADI"
log "PROJECT_DIR=$PROJECT_DIR"
log "RUN_DIR=$RUN_DIR"

cp "$PROJECT_FILE" "$BACKUP_DIR/project.pbxproj.before"
log "BACKUP_ALINDI:$BACKUP_DIR/project.pbxproj.before"

log "MEVCUT_SIGNING_DURUMLARI_CIKARILIYOR"
{
  echo "===== CODE_SIGN / PROVISION / TEAM / BUNDLE BEFORE ====="
  grep -nE 'CODE_SIGN_IDENTITY|CODE_SIGN_STYLE|PROVISIONING_PROFILE|PROVISIONING_PROFILE_SPECIFIER|DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER|CODE_SIGN_ENTITLEMENTS|CODE_SIGNING_ALLOWED|CODE_SIGNING_REQUIRED|CODE_SIGN_INJECT_BASE_ENTITLEMENTS' "$PROJECT_FILE" || true
  echo
  echo "===== TARGETS / CONFIGS ====="
  grep -nE 'PBXNativeTarget|XCBuildConfiguration|XCConfigurationList|name = Debug;|name = Release;' "$PROJECT_FILE" || true
} | tee "$REPORT_DIR/signing_before.txt"

log "PBXPROJ_AUTOMATIC_SIGNING_PATCH_HAZIRLANIYOR"
python3 - <<'PY' "$PROJECT_FILE" "$PATCH_DIR/pbxproj_patch_report.txt"
from pathlib import Path
import re
import sys

project_file = Path(sys.argv[1])
report_file = Path(sys.argv[2])

src = project_file.read_text()
original = src

changes = []

def subn(pattern, repl, text, flags=0, desc=""):
    new_text, n = re.subn(pattern, repl, text, flags=flags)
    if n:
        changes.append(f"{desc}:{n}")
    return new_text

src = subn(r'CODE_SIGN_STYLE = Manual;', 'CODE_SIGN_STYLE = Automatic;', src, desc="CODE_SIGN_STYLE_Manual_to_Automatic")
src = subn(r'CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = "iPhone Distribution";\n', '', src, desc="REMOVE_legacy_iPhoneDistribution_sdk_iphoneos")
src = subn(r'CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = "Apple Distribution";\n', '', src, desc="REMOVE_AppleDistribution_sdk_iphoneos")
src = subn(r'CODE_SIGN_IDENTITY\[sdk=iphoneos\*\] = "Apple Distribution: [^"]+";\n', '', src, desc="REMOVE_named_AppleDistribution_sdk_iphoneos")
src = subn(r'CODE_SIGN_IDENTITY\[sdk=\*\] = "Apple Distribution";\n', '', src, desc="REMOVE_AppleDistribution_sdk_any")
src = subn(r'CODE_SIGN_IDENTITY\[sdk=\*\] = "Apple Distribution: [^"]+";\n', '', src, desc="REMOVE_named_AppleDistribution_sdk_any")
src = subn(r'CODE_SIGN_IDENTITY\[sdk=\*\] = "iPhone Distribution";\n', '', src, desc="REMOVE_legacy_iPhoneDistribution_sdk_any")
src = subn(r'CODE_SIGN_IDENTITY = "iPhone Distribution";', 'CODE_SIGN_IDENTITY = "Apple Development";', src, desc="REWRITE_legacy_iPhoneDistribution_plain")
src = subn(r'CODE_SIGN_IDENTITY = "Apple Distribution";', 'CODE_SIGN_IDENTITY = "Apple Development";', src, desc="REWRITE_AppleDistribution_plain")
src = subn(r'CODE_SIGN_IDENTITY = "Apple Distribution: [^"]+";', 'CODE_SIGN_IDENTITY = "Apple Development";', src, desc="REWRITE_named_AppleDistribution_plain")
src = subn(r'PROVISIONING_PROFILE = "[^"]+";\n', '', src, desc="REMOVE_PROVISIONING_PROFILE_plain")
src = subn(r'PROVISIONING_PROFILE_SPECIFIER = "[^"]+";', 'PROVISIONING_PROFILE_SPECIFIER = "";', src, desc="RESET_PROVISIONING_PROFILE_SPECIFIER")
src = subn(r'CODE_SIGNING_ALLOWED = NO;', 'CODE_SIGNING_ALLOWED = YES;', src, desc="CODE_SIGNING_ALLOWED_NO_to_YES")
src = subn(r'CODE_SIGNING_REQUIRED = NO;', 'CODE_SIGNING_REQUIRED = YES;', src, desc="CODE_SIGNING_REQUIRED_NO_to_YES")

if src != original:
    project_file.write_text(src)

report_file.write_text("\n".join(changes) + ("\nNO_CHANGE\n" if not changes else "\n"))
print("\n".join(changes) if changes else "NO_CHANGE")
PY

cp "$PROJECT_FILE" "$BACKUP_DIR/project.pbxproj.after_patch"
log "PATCH_SONRASI_KOPYA_ALINDI:$BACKUP_DIR/project.pbxproj.after_patch"

log "PATCH_SONRASI_SIGNING_DURUMLARI_CIKARILIYOR"
{
  echo "===== CODE_SIGN / PROVISION / TEAM / BUNDLE AFTER ====="
  grep -nE 'CODE_SIGN_IDENTITY|CODE_SIGN_STYLE|PROVISIONING_PROFILE|PROVISIONING_PROFILE_SPECIFIER|DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER|CODE_SIGN_ENTITLEMENTS|CODE_SIGNING_ALLOWED|CODE_SIGNING_REQUIRED|CODE_SIGN_INJECT_BASE_ENTITLEMENTS' "$PROJECT_FILE" || true
} | tee "$REPORT_DIR/signing_after.txt"

log "ENTITLEMENTS_DOSYALARI_TARANIYOR"
find "$PROJECT_DIR" -type f \( -name "*.entitlements" -o -name "*.plist" -o -name "*.xcprivacy" \) | sort > "$REPORT_DIR/interesting_files.txt"
while IFS= read -r f; do
  {
    echo "===== FILE:$f ====="
    if [[ "$f" == *.plist ]] || [[ "$f" == *.entitlements ]] || [[ "$f" == *.xcprivacy ]]; then
      plutil -p "$f" 2>/dev/null || cat "$f"
    else
      cat "$f"
    fi
    echo
  } >> "$REPORT_DIR/entitlements_and_plists_dump.txt"
done < "$REPORT_DIR/interesting_files.txt"

log "KEYCHAIN_VE_CODESIGN_IDENTITY_DURUMU_TOPLANIYOR"
{
  echo "===== find-identity ====="
  security find-identity -v -p codesigning || true
  echo
  echo "===== default-keychain ====="
  security default-keychain || true
  echo
  echo "===== login-keychain exists ====="
  ls -l ~/Library/Keychains/login.keychain-db || true
  echo
  echo "===== WWDR ====="
  security find-certificate -a -c "Apple Worldwide Developer Relations" /Library/Keychains/System.keychain ~/Library/Keychains/login.keychain-db 2>/dev/null || true
} > "$REPORT_DIR/keychain_and_identity.txt"

log "DERIVED_DATA_TEMIZLENIYOR"
rm -rf ~/Library/Developer/Xcode/DerivedData/QuantumAIMobileApp-* || true

log "XCODEBUILD_SHOWBUILDSETTINGS"
xcodebuild -project "$XCODEPROJ_PATH" -scheme "$SCHEME" -showBuildSettings > "$REPORT_DIR/showBuildSettings.txt" 2>&1 || true

log "SHOWBUILDSETTINGS_ICIN_HEDEF_SATIRLAR_CIKARILIYOR"
grep -nE 'TARGET_NAME =|PRODUCT_BUNDLE_IDENTIFIER =|DEVELOPMENT_TEAM =|CODE_SIGN_STYLE =|CODE_SIGN_IDENTITY =|CODE_SIGN_ENTITLEMENTS =|PROVISIONING_PROFILE =|PROVISIONING_PROFILE_SPECIFIER =|SDKROOT =|SUPPORTED_PLATFORMS =|IPHONEOS_DEPLOYMENT_TARGET =|CODE_SIGNING_ALLOWED =|CODE_SIGNING_REQUIRED =|CODE_SIGN_INJECT_BASE_ENTITLEMENTS =' "$REPORT_DIR/showBuildSettings.txt" > "$REPORT_DIR/showBuildSettings.filtered.txt" || true

log "SIMULATOR_BUILD_BASLATILIYOR"
xcodebuild \
  -project "$XCODEPROJ_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  clean build \
  > "$LOG_DIR/build_simulator.log" 2>&1 || true

log "DEVICE_BUILD_BASLATILIYOR"
xcodebuild \
  -project "$XCODEPROJ_PATH" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination 'generic/platform=iOS' \
  clean build \
  > "$LOG_DIR/build_device.log" 2>&1 || true

log "HATA_AYIKLAMA_OZETLERI_CIKARILIYOR"
{
  echo "===== SIMULATOR BUILD STATUS ====="
  tail -n 50 "$LOG_DIR/build_simulator.log" || true
  echo
  echo "===== DEVICE BUILD STATUS ====="
  tail -n 80 "$LOG_DIR/build_device.log" || true
  echo
  echo "===== BUILD SUCCEEDED / FAILED ====="
  grep -nE '\*\* BUILD SUCCEEDED \*\*|\*\* BUILD FAILED \*\*|error:|CodeSign|Provisioning Profile|Signing Identity|errSec|unable to build chain|conflicting provisioning settings' "$LOG_DIR/build_simulator.log" "$LOG_DIR/build_device.log" || true
} > "$REPORT_DIR/build_summary.txt"

log "SIMULATOR_BUILD_SONUCLARI"
grep -nE '\*\* BUILD SUCCEEDED \*\*|\*\* BUILD FAILED \*\*|error:' "$LOG_DIR/build_simulator.log" | tail -n 20 | tee -a "$LOG_DIR/main.log" || true

log "DEVICE_BUILD_SONUCLARI"
grep -nE '\*\* BUILD SUCCEEDED \*\*|\*\* BUILD FAILED \*\*|error:|CodeSign|Signing Identity|Provisioning Profile|errSec|unable to build chain|conflicting provisioning settings' "$LOG_DIR/build_device.log" | tail -n 40 | tee -a "$LOG_DIR/main.log" || true

log "RAPOR_OLUSTURULUYOR"
cat > "$REPORT_DIR/README_CODESIGN_RESULT.txt" <<REPORT
RUN_DIR=$RUN_DIR

ONEMLI_DOSYALAR:
- $BACKUP_DIR/project.pbxproj.before
- $BACKUP_DIR/project.pbxproj.after_patch
- $PATCH_DIR/pbxproj_patch_report.txt
- $REPORT_DIR/signing_before.txt
- $REPORT_DIR/signing_after.txt
- $REPORT_DIR/showBuildSettings.txt
- $REPORT_DIR/showBuildSettings.filtered.txt
- $REPORT_DIR/keychain_and_identity.txt
- $REPORT_DIR/build_summary.txt
- $LOG_DIR/build_simulator.log
- $LOG_DIR/build_device.log

NE_YAPILDI:
- pbxproj içindeki manuel Distribution / iPhone Distribution override satırları temizlendi
- provisioning profile specifier manuel değerleri sıfırlandı
- CODE_SIGN_STYLE mümkün olduğunda Automatic yapıldı
- DerivedData temizlendi
- simulator ve generic iOS build tetiklendi
- keychain / identity / entitlements / build settings raporlandı
REPORT

log "TAMAMLANDI"
printf '\nRUN_DIR=%s\n' "$RUN_DIR"
printf 'RAPOR=%s\n' "$REPORT_DIR/README_CODESIGN_RESULT.txt"
printf 'SIM_BUILD_LOG=%s\n' "$LOG_DIR/build_simulator.log"
printf 'DEVICE_BUILD_LOG=%s\n' "$LOG_DIR/build_device.log"
