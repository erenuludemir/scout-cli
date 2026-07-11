#!/usr/bin/env bash
set -euo pipefail

REPO_DEFAULT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
REPO="${1:-$REPO_DEFAULT}"
TEAM_ID="${TEAM_ID:-YH698TG69K}"
BUNDLE_ID="${BUNDLE_ID:-com.erenuludemir.quantumaimobile}"
PROFILE_HINT="${PROFILE_HINT:-}"
PROFILE_DST_DIR="$HOME/Library/MobileDevice/Provisioning Profiles"
LOG_DIR="$REPO/_logs/ios_signing_doctor"
TS="$(date +%Y%m%d_%H%M%S)"
RUN_DIR="$LOG_DIR/$TS"
mkdir -p "$RUN_DIR" "$PROFILE_DST_DIR"

[ -d "$REPO" ] || { echo "REPO_YOK:$REPO"; exit 1; }

find_first_dir() {
  local p
  for p in "$@"; do
    [ -d "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

find_first_file() {
  local p
  for p in "$@"; do
    [ -e "$p" ] && { echo "$p"; return 0; }
  done
  return 1
}

IOS_ROOT="$(find_first_dir \
  "$REPO/ios" \
  "$REPO" \
)"
[ -n "${IOS_ROOT:-}" ] || { echo "IOS_ROOT_YOK"; exit 1; }

PKG_DIR="$(find_first_dir \
  "$REPO/ios/QuantumAIMobile" \
  "$REPO/ios" \
)"
[ -n "${PKG_DIR:-}" ] || { echo "PKG_DIR_YOK"; exit 1; }

APP_DIR="$(find_first_dir \
  "$REPO/ios/QuantumAIMobile" \
  "$REPO/ios/QuantumAIMobileApp" \
  "$PKG_DIR" \
)"
[ -n "${APP_DIR:-}" ] || { echo "APP_DIR_YOK:$APP_DIR"; exit 1; }

APP_PROJ="${APP_PROJ:-$(find_first_file \
  "$REPO/ios/QuantumAIMobileApp/QuantumAIMobileApp.xcodeproj" \
  "$REPO/ios/QuantumAIMobile/QuantumAIMobileApp.xcodeproj" \
  "$REPO/ios/QuantumAIMobile/QuantumAIMobile.xcodeproj" \
  "$(find "$REPO/ios" -maxdepth 3 -name "*.xcodeproj" -print 2>/dev/null | head -n 1)" \
)}"

[ -n "${APP_PROJ:-}" ] || { echo "APP_PROJ_YOK"; exit 1; }
[ -e "$APP_PROJ" ] || { echo "APP_PROJ_YOK:$APP_PROJ"; exit 1; }

SCHEME="${SCHEME:-$(basename "$APP_PROJ" .xcodeproj)}"
PROJECT_YML="$(find_first_file \
  "$APP_DIR/project.yml" \
  "$PKG_DIR/project.yml" \
)"
INFO_PLIST="$(find_first_file \
  "$APP_DIR/QuantumAIMobileApp/Info.plist" \
  "$APP_DIR/QuantumAIMobile/Info.plist" \
  "$(find "$APP_DIR" -maxdepth 4 -name "Info.plist" -print 2>/dev/null | head -n 1)" \
)"

exec > >(tee "$RUN_DIR/run.log") 2>&1

echo "REPO=$REPO"
echo "IOS_ROOT=$IOS_ROOT"
echo "APP_DIR=$APP_DIR"
echo "APP_PROJ=$APP_PROJ"
echo "PKG_DIR=$PKG_DIR"
echo "PROJECT_YML=${PROJECT_YML:-}"
echo "INFO_PLIST=${INFO_PLIST:-}"
echo "SCHEME=$SCHEME"
echo "TEAM_ID=$TEAM_ID"
echo "BUNDLE_ID=$BUNDLE_ID"
echo "RUN_DIR=$RUN_DIR"

echo "=== 1) XCODE / TOOLING ==="
{
  echo "DATE=$(date)"
  echo "HOST=$(scutil --get ComputerName 2>/dev/null || hostname)"
  echo "UNAME=$(uname -a)"
  echo "XCODE_SELECT=$(xcode-select -p 2>/dev/null || true)"
  echo "XCODEBUILD_VERSION_BEGIN"
  xcodebuild -version 2>/dev/null || true
  echo "XCODEBUILD_VERSION_END"
  echo "XCODEGEN=$(command -v xcodegen || true)"
  echo "PLUTIL=$(command -v plutil || true)"
  echo "OPENSSL=$(command -v openssl || true)"
  echo "SECURITY=$(command -v security || true)"
} | tee "$RUN_DIR/00_env.txt"

echo "=== 2) CODESIGN IDENTITIES ==="
security find-identity -v -p codesigning "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null | tee "$RUN_DIR/01_identities.txt" || true

VALID_APPLE_DEVELOPMENT_SHA="$(python3 - "$RUN_DIR/01_identities.txt" <<'PY'
from pathlib import Path
import re,sys
txt=Path(sys.argv[1]).read_text(encoding="utf-8",errors="ignore").splitlines()
for line in txt:
    if "Apple Development:" in line and "CSSMERR_TP_CERT_REVOKED" not in line:
        m=re.search(r'\s*[0-9]+\)\s+([0-9A-F]{40})\s+"Apple Development:', line)
        if m:
            print(m.group(1))
            break
PY
)"
VALID_APPLE_DEVELOPMENT_NAME="$(python3 - "$RUN_DIR/01_identities.txt" <<'PY'
from pathlib import Path
import re,sys
txt=Path(sys.argv[1]).read_text(encoding="utf-8",errors="ignore").splitlines()
for line in txt:
    if "Apple Development:" in line and "CSSMERR_TP_CERT_REVOKED" not in line:
        m=re.search(r'"(Apple Development:[^"]+)"', line)
        if m:
            print(m.group(1))
            break
PY
)"
[ -n "${VALID_APPLE_DEVELOPMENT_SHA:-}" ] || { echo "BLOKAJ=VALID_APPLE_DEVELOPMENT_CERT_YOK"; exit 2; }
echo "VALID_APPLE_DEVELOPMENT_SHA=$VALID_APPLE_DEVELOPMENT_SHA"
echo "VALID_APPLE_DEVELOPMENT_NAME=$VALID_APPLE_DEVELOPMENT_NAME"

echo "=== 3) PROFILE HAVUZU TARA ==="
PROFILE_SCAN="$RUN_DIR/02_profiles.tsv"
: > "$PROFILE_SCAN"

scan_profile() {
  local src="$1"
  local plist_out="$2"
  local uuid name team platform appid gta exp prov_all devices_all
  openssl smime -inform der -verify -noverify -in "$src" > "$plist_out" 2>/dev/null || return 0
  uuid="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$plist_out" 2>/dev/null || true)"
  name="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$plist_out" 2>/dev/null || true)"
  team="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$plist_out" 2>/dev/null || true)"
  platform="$(/usr/libexec/PlistBuddy -c 'Print :Platform:0' "$plist_out" 2>/dev/null || true)"
  appid="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$plist_out" 2>/dev/null || /usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' "$plist_out" 2>/dev/null || true)"
  gta="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' "$plist_out" 2>/dev/null || true)"
  exp="$(/usr/libexec/PlistBuddy -c 'Print :ExpirationDate' "$plist_out" 2>/dev/null || true)"
  prov_all="$(/usr/libexec/PlistBuddy -c 'Print :ProvisionsAllDevices' "$plist_out" 2>/dev/null || true)"
  devices_all="$(/usr/libexec/PlistBuddy -c 'Print :ProvisionedDevices' "$plist_out" 2>/dev/null | wc -l | tr -d ' ' || true)"
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$src" "$uuid" "$name" "$team" "$platform" "$appid" "$gta" "$exp" "$prov_all" "$devices_all" >> "$PROFILE_SCAN"
}

while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  scan_profile "$f" "$RUN_DIR/profile_${base//[^A-Za-z0-9._-]/_}.plist"
done < <(
  {
    find "$HOME/Downloads" -maxdepth 1 \( -name "*.mobileprovision" -o -name "*.provisionprofile" \) -print0 2>/dev/null
    find "$PROFILE_DST_DIR" -maxdepth 1 -name "*.mobileprovision" -print0 2>/dev/null
  } | awk 'BEGIN{RS="\0";ORS="\0"} !seen[$0]++ {print}'
)

{
  echo -e "SRC\tUUID\tNAME\tTEAM\tPLATFORM\tAPPID\tGET_TASK_ALLOW\tEXPIRATION\tPROVISIONS_ALL_DEVICES\tPROVISIONED_DEVICE_COUNT"
  cat "$PROFILE_SCAN"
} | tee "$RUN_DIR/03_profiles_pretty.tsv"

echo "=== 4) UYGUN IOS DEVELOPMENT PROFILE SEC ==="
SELECTED_PROFILE="$(python3 - "$PROFILE_SCAN" "$TEAM_ID" "$BUNDLE_ID" "$PROFILE_HINT" <<'PY'
from pathlib import Path
from datetime import datetime
import sys
tsv=Path(sys.argv[1]).read_text(encoding="utf-8",errors="ignore").splitlines()
team_id=sys.argv[2]
bundle_id=sys.argv[3]
hint=sys.argv[4].strip()

def parse_dt(s):
    if not s:
        return datetime.min
    for fmt in ("%a %b %d %H:%M:%S %Z %Y","%a %b %d %H:%M:%S %z %Y"):
        try:
            return datetime.strptime(s, fmt)
        except Exception:
            pass
    return datetime.min

rows=[]
for line in tsv:
    parts=line.split("\t")
    if len(parts) != 10:
        continue
    src,uuid,name,team,platform,appid,gta,exp,prov_all,dev_count=parts
    if hint and hint not in src and hint not in name and hint not in uuid:
        continue
    if team != team_id:
        continue
    if platform != "iOS":
        continue
    if gta.lower() != "true":
        continue
    if not (appid == f"{team_id}.{bundle_id}" or appid == f"{team_id}.*" or (appid.startswith(f"{team_id}.") and bundle_id.startswith(appid[len(team_id)+1:].rstrip("*")))):
        continue
    score=0
    if appid == f"{team_id}.{bundle_id}":
        score += 100
    elif appid == f"{team_id}.*":
        score += 50
    else:
        score += 60
    if dev_count and dev_count.isdigit():
        score += min(int(dev_count), 20)
    if prov_all.lower() == "true":
        score -= 1000
    rows.append((score, parse_dt(exp), src))
rows.sort(key=lambda x:(x[0], x[1]), reverse=True)
print(rows[0][2] if rows else "")
PY
)"

if [ -z "${SELECTED_PROFILE:-}" ]; then
  echo "UYARI=UYGUN_IOS_DEVELOPMENT_PROFILE_BULUNAMADI"
  echo "UYARI=XCODE_OTOMATIK_SIGNING_ILE_DEVAM_EDILECEK"
fi

if [ -n "${SELECTED_PROFILE:-}" ]; then
  echo "SELECTED_PROFILE=$SELECTED_PROFILE"
  PROFILE_PLIST="$RUN_DIR/04_selected_profile.plist"
  openssl smime -inform der -verify -noverify -in "$SELECTED_PROFILE" > "$PROFILE_PLIST" 2>/dev/null
  SELECTED_UUID="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$PROFILE_PLIST" 2>/dev/null || true)"
  SELECTED_NAME="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$PROFILE_PLIST" 2>/dev/null || true)"
  SELECTED_TEAM="$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$PROFILE_PLIST" 2>/dev/null || true)"
  SELECTED_PLATFORM="$(/usr/libexec/PlistBuddy -c 'Print :Platform:0' "$PROFILE_PLIST" 2>/dev/null || true)"
  SELECTED_APPID="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$PROFILE_PLIST" 2>/dev/null || /usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.application-identifier' "$PROFILE_PLIST" 2>/dev/null || true)"
  SELECTED_GTA="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:get-task-allow' "$PROFILE_PLIST" 2>/dev/null || true)"
  SELECTED_EXPIRATION="$(/usr/libexec/PlistBuddy -c 'Print :ExpirationDate' "$PROFILE_PLIST" 2>/dev/null || true)"
  echo "SELECTED_UUID=$SELECTED_UUID"
  echo "SELECTED_NAME=$SELECTED_NAME"
  echo "SELECTED_TEAM=$SELECTED_TEAM"
  echo "SELECTED_PLATFORM=$SELECTED_PLATFORM"
  echo "SELECTED_APPID=$SELECTED_APPID"
  echo "SELECTED_GET_TASK_ALLOW=$SELECTED_GTA"
  echo "SELECTED_EXPIRATION=$SELECTED_EXPIRATION"
  [ "$SELECTED_TEAM" = "$TEAM_ID" ] || { echo "BLOKAJ=SECILEN_PROFILE_TEAM_HATALI"; exit 4; }
  [ "$SELECTED_PLATFORM" = "iOS" ] || { echo "BLOKAJ=SECILEN_PROFILE_IOS_DEGIL"; exit 5; }
  [ "$SELECTED_GTA" = "true" ] || { echo "BLOKAJ=SECILEN_PROFILE_DEVELOPMENT_DEGIL"; exit 6; }
  [ -n "$SELECTED_UUID" ] || { echo "BLOKAJ=SECILEN_PROFILE_UUID_YOK"; exit 7; }
  echo "=== 5) PROFILE KUR ==="
  cp -f "$SELECTED_PROFILE" "$PROFILE_DST_DIR/$SELECTED_UUID.mobileprovision"
  ls -lah "$PROFILE_DST_DIR/$SELECTED_UUID.mobileprovision" | tee "$RUN_DIR/05_installed_profile.txt"
fi

echo "=== 6) project.yml GUNCELLE ==="
if [ -n "${PROJECT_YML:-}" ] && [ -f "$PROJECT_YML" ]; then
python3 - "$PROJECT_YML" "$TEAM_ID" "$BUNDLE_ID" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); team=sys.argv[2]; bundle=sys.argv[3]
t=p.read_text(encoding="utf-8",errors="ignore")
pairs=[
    ("DEVELOPMENT_TEAM", team),
    ("PRODUCT_BUNDLE_IDENTIFIER", bundle),
    ("CODE_SIGN_STYLE", "Automatic"),
    ("CODE_SIGN_IDENTITY", "Apple Development"),
    ("CODE_SIGNING_ALLOWED", "YES"),
    ("CODE_SIGNING_REQUIRED", "YES"),
    ("ENABLE_DEBUG_DYLIB", "NO"),
]
for k,v in pairs:
    if re.search(rf'(^\s*{k}:\s*).+$', t, flags=re.M):
        t=re.sub(rf'(^\s*{k}:\s*).+$', rf'\1{v}', t, flags=re.M)
if "targets:" in t and "settings:" not in t:
    t += "\nsettings:\n  base:\n"
    for k,v in pairs:
        t += f"    {k}: {v}\n"
p.write_text(t,encoding="utf-8")
print("PROJECT_YML_OK")
PY
else
  echo "PROJECT_YML_YOK_ATLANDI"
fi

echo "=== 7) XCODEGEN / PLIST / TEMIZLIK ==="
rm -rf "$APP_DIR/.swiftpm" "$PKG_DIR/.swiftpm" "$PKG_DIR/.build" ~/Library/Developer/Xcode/DerivedData/QuantumAIMobileApp-* ~/Library/Developer/Xcode/DerivedData/QuantumAIMobile-* || true
if [ -f "$PKG_DIR/project.yml" ] && command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate --spec "$PKG_DIR/project.yml" --project "$PKG_DIR/QuantumAIMobile.xcodeproj" | tee "$RUN_DIR/06_pkg_xcodegen.log" || true
fi
if [ -n "${PROJECT_YML:-}" ] && [ -f "$PROJECT_YML" ] && command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate --spec "$PROJECT_YML" --project "$APP_PROJ" | tee "$RUN_DIR/07_app_xcodegen.log" || true
fi
if [ -n "${INFO_PLIST:-}" ] && [ -f "$INFO_PLIST" ]; then
  plutil -lint "$INFO_PLIST" | tee "$RUN_DIR/08_info_plist_lint.log" || true
else
  echo "INFO_PLIST_YOK_ATLANDI" | tee "$RUN_DIR/08_info_plist_lint.log"
fi

echo "=== 8) DESTINATION SEC ==="
xcodebuild -project "$APP_PROJ" -scheme "$SCHEME" -showdestinations 2>&1 | tee "$RUN_DIR/09_showdestinations.log" || true

DESTINATION="$(python3 - "$RUN_DIR/09_showdestinations.log" <<'PY'
from pathlib import Path
import re,sys
lines=Path(sys.argv[1]).read_text(encoding="utf-8",errors="ignore").splitlines()
ios_device=None
ios_sim=None
for line in lines:
    if "platform:iOS," in line and "placeholder" not in line and "id:" in line:
        m=re.search(r'id:([0-9A-Fa-f-]+)', line)
        if m:
            ios_device=f"id={m.group(1)}"
            break
for line in lines:
    if "platform:iOS Simulator" in line and "name:iPhone" in line and "placeholder" not in line and "id:" in line:
        m=re.search(r'id:([0-9A-Fa-f-]+)', line)
        if m:
            ios_sim=f"id={m.group(1)}"
            break
print(ios_device or ios_sim or "generic/platform=iOS Simulator")
PY
)"
echo "DESTINATION=$DESTINATION"

echo "=== 9) BUILD SETTINGS SNAPSHOT ==="
xcodebuild -project "$APP_PROJ" -scheme "$SCHEME" -destination "$DESTINATION" -showBuildSettings 2>&1 | tee "$RUN_DIR/10_buildsettings.log" || true
grep -E "DEVELOPMENT_TEAM =|PRODUCT_BUNDLE_IDENTIFIER =|CODE_SIGN_STYLE =|CODE_SIGN_IDENTITY =|PROVISIONING_PROFILE_SPECIFIER =|PROVISIONING_PROFILE =|CODE_SIGNING_ALLOWED =|CODE_SIGNING_REQUIRED =" "$RUN_DIR/10_buildsettings.log" | tee "$RUN_DIR/11_buildsettings_signing_extract.txt" || true

echo "=== 10) CLEAN BUILD ==="
xcodebuild \
  -project "$APP_PROJ" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -configuration Debug \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  -derivedDataPath "$RUN_DIR/DerivedData" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGN_STYLE=Automatic \
  CODE_SIGN_IDENTITY="Apple Development" \
  clean build 2>&1 | tee "$RUN_DIR/12_build.log" || true

echo "=== 11) HATA OZETI ==="
grep -nE "Signing Identity:|Provisioning Profile:|error:|errSecInternalComponent|unable to build chain|CodeSign |requires a provisioning profile|No profiles for|No signing certificate|CSSMERR_TP_CERT_REVOKED" "$RUN_DIR/12_build.log" | tee "$RUN_DIR/13_error_extract.txt" || true

echo "=== 12) SONUC ==="
BUILD_OK=0
grep -q "\*\* BUILD SUCCEEDED \*\*" "$RUN_DIR/12_build.log" && BUILD_OK=1 || true
{
  echo "RUN_DIR=$RUN_DIR"
  echo "APP_DIR=$APP_DIR"
  echo "APP_PROJ=$APP_PROJ"
  echo "PKG_DIR=$PKG_DIR"
  echo "SCHEME=$SCHEME"
  echo "VALID_APPLE_DEVELOPMENT_SHA=$VALID_APPLE_DEVELOPMENT_SHA"
  echo "VALID_APPLE_DEVELOPMENT_NAME=$VALID_APPLE_DEVELOPMENT_NAME"
  echo "SELECTED_PROFILE=${SELECTED_PROFILE:-}"
  echo "DESTINATION=$DESTINATION"
  echo "BUILD_OK=$BUILD_OK"
} | tee "$RUN_DIR/99_summary.txt"

if [ "$BUILD_OK" = "1" ]; then
  echo "IOS_SIGNING_DOCTOR_OK"
  exit 0
fi

echo "IOS_SIGNING_DOCTOR_FAIL"
exit 9
