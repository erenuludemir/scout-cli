#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

PROJECT_DIR="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ios/QuantumAIMobileApp"
XCODEPROJ_PATH="$PROJECT_DIR/QuantumAIMobileApp.xcodeproj"
SCHEME="QuantumAIMobileApp"
OUT_DIR="$PROJECT_DIR/_codesign_repair_tools/keychain_reset_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT_DIR"

log(){ printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$OUT_DIR/run.log"; }

log "KEYCHAIN_UNLOCK"
security unlock-keychain ~/Library/Keychains/login.keychain-db || true
security default-keychain -s ~/Library/Keychains/login.keychain-db || true

log "CODESIGN_IDENTITIES_BEFORE"
security find-identity -v -p codesigning | tee "$OUT_DIR/find_identity_before.txt" || true

log "WWDR_BEFORE"
security find-certificate -a -c "Apple Worldwide Developer Relations" /Library/Keychains/System.keychain ~/Library/Keychains/login.keychain-db > "$OUT_DIR/wwdr_before.txt" 2>&1 || true

log "APPLE_DEV_CERTS_BEFORE"
security find-certificate -a -c "Apple Development" ~/Library/Keychains/login.keychain-db > "$OUT_DIR/apple_development_before.txt" 2>&1 || true

log "APPLE_DIST_CERTS_BEFORE"
security find-certificate -a -c "Apple Distribution" ~/Library/Keychains/login.keychain-db > "$OUT_DIR/apple_distribution_before.txt" 2>&1 || true

log "PROJECT_SIGNING_SNAPSHOT"
grep -nE 'CODE_SIGN_IDENTITY|CODE_SIGN_STYLE|PROVISIONING_PROFILE|PROVISIONING_PROFILE_SPECIFIER|DEVELOPMENT_TEAM|PRODUCT_BUNDLE_IDENTIFIER' "$XCODEPROJ_PATH/project.pbxproj" > "$OUT_DIR/project_signing_snapshot.txt" || true

log "DERIVEDDATA_DELETE"
rm -rf ~/Library/Developer/Xcode/DerivedData/QuantumAIMobileApp-* || true

log "SIMULATOR_BUILD_CHECK"
xcodebuild -project "$XCODEPROJ_PATH" -scheme "$SCHEME" -configuration Debug -destination 'generic/platform=iOS Simulator' clean build > "$OUT_DIR/simulator_build.log" 2>&1 || true
grep -nE '\*\* BUILD SUCCEEDED \*\*|\*\* BUILD FAILED \*\*|error:|warning:' "$OUT_DIR/simulator_build.log" > "$OUT_DIR/simulator_build.filtered.txt" || true

log "DEVICE_BUILD_CHECK"
xcodebuild -project "$XCODEPROJ_PATH" -scheme "$SCHEME" -configuration Debug -destination 'generic/platform=iOS' clean build > "$OUT_DIR/device_build.log" 2>&1 || true
grep -nE 'CodeSign|Signing Identity|Provisioning Profile|unable to build chain|errSecInternalComponent|\*\* BUILD SUCCEEDED \*\*|\*\* BUILD FAILED \*\*|error:' "$OUT_DIR/device_build.log" > "$OUT_DIR/device_build.filtered.txt" || true

cat > "$OUT_DIR/NEXT_STEPS.txt" <<'TXT'
TANI:
- Simulator build başarılıysa proje signing ayarı temizdir.
- Device build 'unable to build chain to self-signed root' + 'errSecInternalComponent' veriyorsa sorun keychain/certificate chain tarafındadır.

XCODE GUI ADIMLARI:
1) Xcode > Settings > Accounts
2) Apple ID hesabını seç
3) Team seç
4) Manage Certificates
5) Apple Development sertifikasını sil
6) Apple Distribution sertifikasında bozuk/eski kopya varsa sil
7) + butonu ile Apple Development sertifikasını yeniden oluştur
8) Xcode'u tamamen kapat
9) Keychain Access aç
10) login > My Certificates altında yeni Apple Development sertifikasının PRIVATE KEY ile birlikte geldiğini doğrula
11) Sertifikaya çift tıkla > Trust > Use System Defaults
12) Eski kırmızı çarpılı / private key'siz Apple Development kopyalarını sil
13) Xcode'u tekrar aç
14) Product > Clean Build Folder
15) Önce iPhone Simulator build al
16) Sonra gerçek cihaz build al

EK KONTROL:
- iPhone fiziksel cihazı bağlıysa cihaz üzerinde Developer Mode açık olsun
- Cihaz ve Mac aynı Apple geliştirici takımı altında olsun
- Keychain kilitli olmasın
TXT

printf 'OUT_DIR=%s\n' "$OUT_DIR"
