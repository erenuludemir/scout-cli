#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3}"
APP_DIR="$REPO/ios/QuantumAIMobileApp"
PKG_DIR="$REPO/ios/QuantumAIMobile"
APP_PROJECT_YML="$APP_DIR/project.yml"
PKG_PROJECT_YML="$PKG_DIR/project.yml"
APP_PROJ="$APP_DIR/QuantumAIMobileApp.xcodeproj"
PKG_PROJ="$PKG_DIR/QuantumAIMobile.xcodeproj"
TEAM_ID="${TEAM_ID:-YH698TG69K}"
BUNDLE_ID="${BUNDLE_ID:-com.erenuludemir.quantumaimobile}"
APP_NAME="${APP_NAME:-QuantumAIMobileApp}"
PKG_NAME="${PKG_NAME:-QuantumAIMobile}"
IOS_DEPLOYMENT_TARGET="${IOS_DEPLOYMENT_TARGET:-17.0}"
SWIFT_VERSION="${SWIFT_VERSION:-5.0}"
DESTINATION_ID="${DESTINATION_ID:-AF6866D4-B3FF-413E-8414-ACCF7B8741CF}"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$REPO/_backups/xcode_build_settings/$TS"
LOG_DIR="$REPO/_logs/xcode_build_settings_revise/$TS"

mkdir -p "$BACKUP_DIR" "$LOG_DIR" "$APP_DIR/Configs" "$PKG_DIR/Configs"

[ -d "$REPO" ] || { echo "REPO_YOK:$REPO"; exit 1; }
[ -d "$APP_DIR" ] || { echo "APP_DIR_YOK:$APP_DIR"; exit 1; }
[ -d "$PKG_DIR" ] || { echo "PKG_DIR_YOK:$PKG_DIR"; exit 1; }
[ -f "$APP_PROJECT_YML" ] || { echo "APP_PROJECT_YML_YOK:$APP_PROJECT_YML"; exit 1; }
[ -f "$PKG_PROJECT_YML" ] || { echo "PKG_PROJECT_YML_YOK:$PKG_PROJECT_YML"; exit 1; }

exec > >(tee "$LOG_DIR/run.log") 2>&1

echo "REPO=$REPO"
echo "APP_DIR=$APP_DIR"
echo "PKG_DIR=$PKG_DIR"
echo "TEAM_ID=$TEAM_ID"
echo "BUNDLE_ID=$BUNDLE_ID"
echo "IOS_DEPLOYMENT_TARGET=$IOS_DEPLOYMENT_TARGET"
echo "SWIFT_VERSION=$SWIFT_VERSION"
echo "BACKUP_DIR=$BACKUP_DIR"
echo "LOG_DIR=$LOG_DIR"

backup_if_exists() {
  local f="$1"
  [ -e "$f" ] && cp -R "$f" "$BACKUP_DIR/"
}

backup_if_exists "$APP_PROJECT_YML"
backup_if_exists "$PKG_PROJECT_YML"
backup_if_exists "$APP_PROJ"
backup_if_exists "$PKG_PROJ"
backup_if_exists "$APP_DIR/QuantumAIMobileApp/Info.plist"
backup_if_exists "$PKG_DIR/QuantumAIMobile/Info.plist"

cat > "$APP_DIR/Configs/Base.xcconfig" <<EOF
PRODUCT_NAME = \$(TARGET_NAME)
PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID
DEVELOPMENT_TEAM = $TEAM_ID
CODE_SIGN_STYLE = Automatic
CODE_SIGN_IDENTITY[sdk=iphoneos*] = Apple Development
CODE_SIGNING_ALLOWED = YES
CODE_SIGNING_REQUIRED = YES
CODE_SIGN_INJECT_BASE_ENTITLEMENTS = YES
SUPPORTED_PLATFORMS = iphoneos iphonesimulator
SDKROOT = iphoneos
TARGETED_DEVICE_FAMILY = 1,2
IPHONEOS_DEPLOYMENT_TARGET = $IOS_DEPLOYMENT_TARGET
SWIFT_VERSION = $SWIFT_VERSION
SWIFT_STRICT_CONCURRENCY = minimal
SWIFT_TREAT_WARNINGS_AS_ERRORS = NO
ENABLE_USER_SCRIPT_SANDBOXING = YES
ENABLE_PREVIEWS = YES
ENABLE_TESTABILITY = YES
ENABLE_DEBUG_DYLIB = NO
GENERATE_INFOPLIST_FILE = NO
INFOPLIST_FILE = QuantumAIMobileApp/Info.plist
ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon
ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor
CURRENT_PROJECT_VERSION = 1
MARKETING_VERSION = 1.0.0
VERSIONING_SYSTEM = apple-generic
PRODUCT_MODULE_NAME = QuantumAIMobileApp
APPLICATION_EXTENSION_API_ONLY = NO
SUPPORTS_MACCATALYST = NO
SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO
ONLY_ACTIVE_ARCH[config=Debug] = YES
ONLY_ACTIVE_ARCH[config=Release] = NO
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
COPY_PHASE_STRIP = NO
STRIP_INSTALLED_PRODUCT = NO
LD_RUNPATH_SEARCH_PATHS = \$(inherited) @executable_path/Frameworks
EOF

cat > "$APP_DIR/Configs/Debug.xcconfig" <<'EOF'
#include "Base.xcconfig"
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) DEBUG=1
ENABLE_TESTABILITY = YES
COPY_PHASE_STRIP = NO
STRIP_SWIFT_SYMBOLS = NO
EOF

cat > "$APP_DIR/Configs/Release.xcconfig" <<'EOF'
#include "Base.xcconfig"
SWIFT_COMPILATION_MODE = wholemodule
ENABLE_TESTABILITY = NO
COPY_PHASE_STRIP = YES
STRIP_SWIFT_SYMBOLS = YES
EOF

cat > "$PKG_DIR/Configs/Base.xcconfig" <<EOF
PRODUCT_NAME = \$(TARGET_NAME)
DEVELOPMENT_TEAM = $TEAM_ID
CODE_SIGN_STYLE = Automatic
CODE_SIGN_IDENTITY[sdk=iphoneos*] = Apple Development
SUPPORTED_PLATFORMS = iphoneos iphonesimulator
SDKROOT = iphoneos
TARGETED_DEVICE_FAMILY = 1,2
IPHONEOS_DEPLOYMENT_TARGET = $IOS_DEPLOYMENT_TARGET
SWIFT_VERSION = $SWIFT_VERSION
SWIFT_STRICT_CONCURRENCY = minimal
SWIFT_TREAT_WARNINGS_AS_ERRORS = NO
ENABLE_USER_SCRIPT_SANDBOXING = YES
ENABLE_TESTABILITY = YES
ENABLE_DEBUG_DYLIB = NO
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
COPY_PHASE_STRIP = NO
STRIP_INSTALLED_PRODUCT = NO
SUPPORTS_MACCATALYST = NO
SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD = NO
ONLY_ACTIVE_ARCH[config=Debug] = YES
ONLY_ACTIVE_ARCH[config=Release] = NO
EOF

cat > "$PKG_DIR/Configs/Debug.xcconfig" <<'EOF'
#include "Base.xcconfig"
SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG
GCC_PREPROCESSOR_DEFINITIONS = $(inherited) DEBUG=1
ENABLE_TESTABILITY = YES
EOF

cat > "$PKG_DIR/Configs/Release.xcconfig" <<'EOF'
#include "Base.xcconfig"
SWIFT_COMPILATION_MODE = wholemodule
ENABLE_TESTABILITY = NO
EOF

python3 - "$APP_PROJECT_YML" "$TEAM_ID" "$BUNDLE_ID" "$IOS_DEPLOYMENT_TARGET" "$SWIFT_VERSION" "$APP_NAME" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1])
team,bundle,ios_target,swift_ver,app_name=sys.argv[2:]
t=p.read_text(encoding="utf-8",errors="ignore")

pairs = {
    "DEVELOPMENT_TEAM": team,
    "PRODUCT_BUNDLE_IDENTIFIER": bundle,
    "CODE_SIGN_STYLE": "Automatic",
    "CODE_SIGN_IDENTITY": "Apple Development",
    "CODE_SIGNING_ALLOWED": "YES",
    "CODE_SIGNING_REQUIRED": "YES",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
    "SDKROOT": "iphoneos",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
    "IPHONEOS_DEPLOYMENT_TARGET": ios_target,
    "SWIFT_VERSION": swift_ver,
    "SWIFT_STRICT_CONCURRENCY": "minimal",
    "ENABLE_DEBUG_DYLIB": "NO",
    "GENERATE_INFOPLIST_FILE": "NO",
    "INFOPLIST_FILE": "QuantumAIMobileApp/Info.plist",
    "PRODUCT_NAME": app_name,
    "PRODUCT_MODULE_NAME": app_name,
    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
    "SUPPORTS_MACCATALYST": "NO",
    "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD": "NO",
}

if "settingGroups:" not in t:
    insert = """
settingGroups:
  qaiBase:
    DEVELOPMENT_TEAM: {DEVELOPMENT_TEAM}
    PRODUCT_BUNDLE_IDENTIFIER: {PRODUCT_BUNDLE_IDENTIFIER}
    CODE_SIGN_STYLE: Automatic
    CODE_SIGN_IDENTITY: Apple Development
    CODE_SIGNING_ALLOWED: YES
    CODE_SIGNING_REQUIRED: YES
    SUPPORTED_PLATFORMS: iphoneos iphonesimulator
    SDKROOT: iphoneos
    TARGETED_DEVICE_FAMILY: "1,2"
    IPHONEOS_DEPLOYMENT_TARGET: {IPHONEOS_DEPLOYMENT_TARGET}
    SWIFT_VERSION: {SWIFT_VERSION}
    SWIFT_STRICT_CONCURRENCY: minimal
    ENABLE_DEBUG_DYLIB: NO
    GENERATE_INFOPLIST_FILE: NO
    INFOPLIST_FILE: QuantumAIMobileApp/Info.plist
    PRODUCT_NAME: {PRODUCT_NAME}
    PRODUCT_MODULE_NAME: {PRODUCT_MODULE_NAME}
    ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
    ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor
    SUPPORTS_MACCATALYST: NO
    SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD: NO
""".format(**pairs)
    if "include:" in t:
        t = t.replace("include:\n", "include:\n" + insert + "\n", 1)
    else:
        t = insert + "\n" + t

if "configs:" not in t:
    t += """
configs:
  Debug: debug
  Release: release
"""

if "configFiles:" not in t:
    t += """
configFiles:
  Debug: Configs/Debug.xcconfig
  Release: Configs/Release.xcconfig
"""

if "settings:" not in t:
    t += """
settings:
  base:
"""
for k,v in pairs.items():
    if not re.search(rf'(^\s*{re.escape(k)}:\s*).+$', t, flags=re.M):
        t += f"    {k}: {v}\n"

if "groups:" not in t:
    t += """
groups:
  - QuantumAIMobileApp
  - Configs
"""

if "Configs" not in t:
    t += """
fileGroups:
  - Configs
"""

p.write_text(t,encoding="utf-8")
print("APP_PROJECT_YML_PATCH_OK")
PY

python3 - "$PKG_PROJECT_YML" "$TEAM_ID" "$IOS_DEPLOYMENT_TARGET" "$SWIFT_VERSION" "$PKG_NAME" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1])
team,ios_target,swift_ver,pkg_name=sys.argv[2:]
t=p.read_text(encoding="utf-8",errors="ignore")

pairs = {
    "DEVELOPMENT_TEAM": team,
    "CODE_SIGN_STYLE": "Automatic",
    "CODE_SIGN_IDENTITY": "Apple Development",
    "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
    "SDKROOT": "iphoneos",
    "TARGETED_DEVICE_FAMILY": '"1,2"',
    "IPHONEOS_DEPLOYMENT_TARGET": ios_target,
    "SWIFT_VERSION": swift_ver,
    "SWIFT_STRICT_CONCURRENCY": "minimal",
    "ENABLE_DEBUG_DYLIB": "NO",
    "PRODUCT_NAME": pkg_name,
    "SUPPORTS_MACCATALYST": "NO",
    "SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD": "NO",
}

if "settingGroups:" not in t:
    insert = """
settingGroups:
  qaiBase:
    DEVELOPMENT_TEAM: {DEVELOPMENT_TEAM}
    CODE_SIGN_STYLE: Automatic
    CODE_SIGN_IDENTITY: Apple Development
    SUPPORTED_PLATFORMS: iphoneos iphonesimulator
    SDKROOT: iphoneos
    TARGETED_DEVICE_FAMILY: "1,2"
    IPHONEOS_DEPLOYMENT_TARGET: {IPHONEOS_DEPLOYMENT_TARGET}
    SWIFT_VERSION: {SWIFT_VERSION}
    SWIFT_STRICT_CONCURRENCY: minimal
    ENABLE_DEBUG_DYLIB: NO
    PRODUCT_NAME: {PRODUCT_NAME}
    SUPPORTS_MACCATALYST: NO
    SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD: NO
""".format(**pairs)
    if "include:" in t:
        t = t.replace("include:\n", "include:\n" + insert + "\n", 1)
    else:
        t = insert + "\n" + t

if "configs:" not in t:
    t += """
configs:
  Debug: debug
  Release: release
"""

if "configFiles:" not in t:
    t += """
configFiles:
  Debug: Configs/Debug.xcconfig
  Release: Configs/Release.xcconfig
"""

if "settings:" not in t:
    t += """
settings:
  base:
"""
for k,v in pairs.items():
    if not re.search(rf'(^\s*{re.escape(k)}:\s*).+$', t, flags=re.M):
        t += f"    {k}: {v}\n"

if "groups:" not in t:
    t += """
groups:
  - QuantumAIMobile
  - Configs
"""

if "Configs" not in t:
    t += """
fileGroups:
  - Configs
"""

p.write_text(t,encoding="utf-8")
print("PKG_PROJECT_YML_PATCH_OK")
PY

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate --spec "$PKG_PROJECT_YML" --project "$PKG_PROJ" 2>&1 | tee "$LOG_DIR/01_xcodegen_pkg.log"
  xcodegen generate --spec "$APP_PROJECT_YML" --project "$APP_PROJ" 2>&1 | tee "$LOG_DIR/02_xcodegen_app.log"
else
  echo "XCODEGEN_YOK" | tee "$LOG_DIR/01_xcodegen_pkg.log"
  echo "XCODEGEN_YOK" | tee "$LOG_DIR/02_xcodegen_app.log"
  exit 2
fi

plutil -lint "$APP_DIR/QuantumAIMobileApp/Info.plist" 2>&1 | tee "$LOG_DIR/03_app_infoplist_lint.log" || true
find "$REPO/ios" -name "*.xcodeproj" -maxdepth 3 -print | tee "$LOG_DIR/04_xcodeproj_list.txt"

xcodebuild -project "$APP_PROJ" -scheme "$APP_NAME" -showBuildSettings 2>&1 | tee "$LOG_DIR/05_buildsettings.txt" || true

grep -E "PRODUCT_BUNDLE_IDENTIFIER =|DEVELOPMENT_TEAM =|CODE_SIGN_STYLE =|CODE_SIGN_IDENTITY =|SUPPORTED_PLATFORMS =|SDKROOT =|TARGETED_DEVICE_FAMILY =|IPHONEOS_DEPLOYMENT_TARGET =|SWIFT_VERSION =|SWIFT_STRICT_CONCURRENCY =|INFOPLIST_FILE =|GENERATE_INFOPLIST_FILE =|SUPPORTS_MACCATALYST =|SUPPORTS_XR_DESIGNED_FOR_IPHONE_IPAD =" "$LOG_DIR/05_buildsettings.txt" | tee "$LOG_DIR/06_buildsettings_extract.txt" || true

rm -rf ~/Library/Developer/Xcode/DerivedData/QuantumAIMobileApp-* ~/Library/Developer/Xcode/DerivedData/QuantumAIMobile-* || true

xcodebuild \
  -project "$APP_PROJ" \
  -scheme "$APP_NAME" \
  -destination "id=$DESTINATION_ID" \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  clean build 2>&1 | tee "$LOG_DIR/07_simulator_build.log" || true

BUILD_OK=0
grep -q "\*\* BUILD SUCCEEDED \*\*" "$LOG_DIR/07_simulator_build.log" && BUILD_OK=1 || true

{
  echo "REPO=$REPO"
  echo "APP_DIR=$APP_DIR"
  echo "PKG_DIR=$PKG_DIR"
  echo "APP_PROJECT_YML=$APP_PROJECT_YML"
  echo "PKG_PROJECT_YML=$PKG_PROJECT_YML"
  echo "APP_PROJ=$APP_PROJ"
  echo "PKG_PROJ=$PKG_PROJ"
  echo "TEAM_ID=$TEAM_ID"
  echo "BUNDLE_ID=$BUNDLE_ID"
  echo "IOS_DEPLOYMENT_TARGET=$IOS_DEPLOYMENT_TARGET"
  echo "SWIFT_VERSION=$SWIFT_VERSION"
  echo "BACKUP_DIR=$BACKUP_DIR"
  echo "LOG_DIR=$LOG_DIR"
  echo "BUILD_OK=$BUILD_OK"
} | tee "$LOG_DIR/99_summary.txt"

echo "TAMAMLANDI_LOG=$LOG_DIR"
echo "TAMAMLANDI_BACKUP=$BACKUP_DIR"
