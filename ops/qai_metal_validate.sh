#!/usr/bin/env bash
set -euo pipefail

REPO_DEFAULT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
REPO="${1:-$REPO_DEFAULT}"

[ -d "$REPO" ] || { echo "REPO_YOK:$REPO"; exit 1; }

TS="$(date +%Y%m%d_%H%M%S)"
OUT="$REPO/_metal_toolchain_check_$TS"
mkdir -p "$OUT"

echo "REPO=$REPO"
echo "OUT=$OUT"

echo "=== 1) METAL/XCODE ARACLARI TESPIT ==="
{
  echo "DATE=$(date)"
  echo "HOST=$(scutil --get ComputerName 2>/dev/null || hostname)"
  echo "UNAME=$(uname -a)"
  echo "XCODE_SELECT=$(xcode-select -p 2>/dev/null || true)"
  echo "DEVELOPER_DIR=${DEVELOPER_DIR:-}"
  echo "XCODEBUILD_VERSION_BEGIN"
  xcodebuild -version 2>/dev/null || true
  echo "XCODEBUILD_VERSION_END"
  echo "XCRUN_PATH=$(command -v xcrun || true)"
  echo "METAL_PATH=$(xcrun -f metal 2>/dev/null || true)"
  echo "METALLIB_PATH=$(xcrun -f metallib 2>/dev/null || true)"
  echo "METAL_NM_PATH=$(xcrun -f metal-nm 2>/dev/null || true)"
  echo "METAL_OBJDUMP_PATH=$(xcrun -f metal-objdump 2>/dev/null || true)"
} | tee "$OUT/00_env.txt"

echo "=== 2) REPO ALTINDA Metal.xctoolchain ve RestoreVersion.plist ARAMA ==="
find "$REPO" \( -name "Metal.xctoolchain" -o -name "RestoreVersion.plist" -o -name "version.plist" -o -name "ToolchainInfo.plist" -o -name "ToolchainInfo.json" \) -print 2>/dev/null | sort | tee "$OUT/01_repo_hits.txt"

echo "=== 3) SISTEM CAPINDA METAL TOOLCHAIN LOKASYONLARI ==="
find /Applications /Library /System /opt "$HOME" -name "Metal.xctoolchain" -type d -print 2>/dev/null | sort | tee "$OUT/02_system_toolchains.txt" || true

echo "=== 4) SURUM/PLIST ICERIKLERI ==="
: > "$OUT/03_plists_dump.txt"
while IFS= read -r f; do
  echo "----- FILE:$f" | tee -a "$OUT/03_plists_dump.txt"
  plutil -p "$f" 2>/dev/null | tee -a "$OUT/03_plists_dump.txt" || cat "$f" | tee -a "$OUT/03_plists_dump.txt"
  echo | tee -a "$OUT/03_plists_dump.txt"
done < <(grep -E 'RestoreVersion\.plist|version\.plist|ToolchainInfo\.plist|ToolchainInfo\.json' "$OUT/01_repo_hits.txt" || true)

echo "=== 5) CLI MAN/HELP DOGRULAMA ==="
{
  echo "METAL_HELP_BEGIN"
  { xcrun metal -help 2>&1 | head -n 80; } || true
  echo "METAL_HELP_END"
  echo "METALLIB_HELP_BEGIN"
  { xcrun metallib -help 2>&1 | head -n 80; } || true
  echo "METALLIB_HELP_END"
  echo "MAN_METAL_BEGIN"
  { man metal 2>/dev/null | col -bx | head -n 80; } || true
  echo "MAN_METAL_END"
  echo "MAN_METALLIB_BEGIN"
  { man metallib 2>/dev/null | col -bx | head -n 80; } || true
  echo "MAN_METALLIB_END"
} | tee "$OUT/04_cli_help.txt"

echo "=== 6) TEST SHADER DOSYASI OLUSTURMA ==="
cat > "$OUT/TestShader.metal" <<'METAL'
#include <metal_stdlib>
using namespace metal;

kernel void qai_add_one(device const float *inVector [[buffer(0)]],
                        device float *outVector [[buffer(1)]],
                        uint id [[thread_position_in_grid]]) {
    outVector[id] = inVector[id] + 1.0;
}
METAL

echo "=== 7) metal -> .air DERLEME ==="
xcrun -sdk macosx metal -c "$OUT/TestShader.metal" -o "$OUT/TestShader.air" 2>&1 | tee "$OUT/05_metal_compile.log"
test -f "$OUT/TestShader.air"
echo "OK_AIR=$OUT/TestShader.air"

echo "=== 8) .air -> .metallib DERLEME ==="
xcrun -sdk macosx metallib "$OUT/TestShader.air" -o "$OUT/TestShader.metallib" 2>&1 | tee "$OUT/06_metallib_compile.log"
test -f "$OUT/TestShader.metallib"
echo "OK_METALLIB=$OUT/TestShader.metallib"

echo "=== 9) IKINCIL ARACLARLA KONTROL ==="
{
  echo "FILE_BEGIN"
  file "$OUT/TestShader.air" "$OUT/TestShader.metallib"
  echo "FILE_END"
  echo "LS_BEGIN"
  ls -lh "$OUT/TestShader.air" "$OUT/TestShader.metallib"
  echo "LS_END"
  echo "NM_BEGIN"
  xcrun metal-nm "$OUT/TestShader.metallib" 2>/dev/null || true
  echo "NM_END"
  echo "OBJDUMP_BEGIN"
  { xcrun metal-objdump --help 2>/dev/null | head -n 40; } || true
  echo "OBJDUMP_END"
} | tee "$OUT/07_artifact_checks.txt"

echo "=== 10) PERFORMANS ICIN DOGRU KULLANIM SENARYOSU DOSYASI ==="
cat > "$OUT/08_performance_scenario.md" <<'MD'
# Metal.xctoolchain Dogru Kullanim Senaryosu

## En iyi kullanim alanlari
- Apple Silicon macOS uygulamalari
- iPhone/iPad hedefli GPU compute veya render
- visionOS / tvOS / watchOS hedefli shader kutuphaneleri
- Oyun, 3D render, goruntu isleme, compute kernel, ML on/son isleme

## Dogru pratik akis
1. `.metal` kaynaklarini repo icinde ayri klasorde tut
2. build sirasinda `metal` ile `.air` uret
3. `metallib` ile tekil veya birlesik `.metallib` uret
4. debug ve profiling icin ayri build profili kullan
5. gercek performans olcumunu Xcode debug validation kapali veya release kosulunda yap
6. cok hedefli uretimde `-sdk macosx`, `iphoneos`, `iphonesimulator`, `xros`, `xrsimulator` gibi hedefleri ayri derle
7. shader kutuphanesini uygulama acilisinda degil build asamasinda onceden uret

## Bu repo icin mantikli entegrasyon
- GPU yogun moduller varsa:
  - goruntu isleme
  - render/visualization
  - tensor/compute on isleme
  - simulasyon acceleration
- CLI/servis tabanli backend ise Metal yalnizca gercekten GPU compute ihtiyaci varsa eklenmeli
- Saf Docker/Linux container icinde Metal beklenmez; Metal en iyi host macOS tarafinda, native Apple runtime ile calisir

## Hiz/performans notlari
- Debug layer / API validation gelistirmede faydalidir ama performans olcumunu bozar
- Onceden derlenmis `.metallib`, runtime compile yukunu azaltir
- Apple Silicon uzerinde native calistirma, sanallastirilmis veya uyumsuz katmanlardan daha uygundur

## Ne zaman kullanma
- Sadece CPU-bound Python servislerinde
- Headless Linux container is akislarinda
- GPU compute gerektirmeyen klasik backend gorevlerinde
MD

echo "=== 11) IOS SIGNING TANISI ==="
{
  echo "IOS_CODESIGN_IDENTITIES_BEGIN"
  security find-identity -v -p codesigning "$HOME/Library/Keychains/login.keychain-db" 2>/dev/null || true
  echo "IOS_CODESIGN_IDENTITIES_END"
  echo "IOS_DEV_PROFILE_FILES_BEGIN"
  find "$HOME/Library/MobileDevice/Provisioning Profiles" -name "*.mobileprovision" -maxdepth 1 -print 2>/dev/null || true
  echo "IOS_DEV_PROFILE_FILES_END"
} | tee "$OUT/09_ios_signing_diagnosis.txt"

echo "=== 12) REPO ICIN OPS RUNBOOK ==="
cat > "$OUT/10_repo_usage.txt" <<EOF
CALISTIR:
bash "$REPO/ops/qai_metal_validate.sh"
VEYA:
bash "$REPO/ops/qai_metal_validate.sh" "$REPO"

CIKTI_DIZINI:
$OUT

ONEMLI_DOSYALAR:
$OUT/00_env.txt
$OUT/01_repo_hits.txt
$OUT/02_system_toolchains.txt
$OUT/03_plists_dump.txt
$OUT/04_cli_help.txt
$OUT/05_metal_compile.log
$OUT/06_metallib_compile.log
$OUT/07_artifact_checks.txt
$OUT/08_performance_scenario.md
$OUT/09_ios_signing_diagnosis.txt
$OUT/99_summary.txt
EOF

echo "=== 13) OZET RAPOR ==="
{
  echo "METAL_TOOLCHAIN_CHECK_OK=1"
  echo "OUTPUT_DIR=$OUT"
  echo "METAL_BIN=$(xcrun -f metal 2>/dev/null || true)"
  echo "METALLIB_BIN=$(xcrun -f metallib 2>/dev/null || true)"
  echo "AIR_EXISTS=$(test -f "$OUT/TestShader.air" && echo YES || echo NO)"
  echo "METALLIB_EXISTS=$(test -f "$OUT/TestShader.metallib" && echo YES || echo NO)"
  echo "REPO_HITS_COUNT=$(wc -l < "$OUT/01_repo_hits.txt" | tr -d ' ')"
  echo "SYSTEM_TOOLCHAINS_COUNT=$(wc -l < "$OUT/02_system_toolchains.txt" | tr -d ' ')"
} | tee "$OUT/99_summary.txt"

echo "TAMAMLANDI:$OUT"
