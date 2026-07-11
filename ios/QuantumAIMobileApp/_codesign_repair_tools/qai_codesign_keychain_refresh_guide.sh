#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

OUT_DIR="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ios/QuantumAIMobileApp/_codesign_repair_tools/keychain_refresh_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT_DIR"

{
  echo "1) Xcode > Settings > Accounts"
  echo "2) Apple ID hesabini sec"
  echo "3) Team'i sec"
  echo "4) Manage Certificates"
  echo "5) Eski / bozuk Apple Development ve Apple Distribution sertifikalarini sil"
  echo "6) + butonu ile Apple Development sertifikasi yeniden olustur"
  echo "7) Keychain Access ac"
  echo "8) login > My Certificates altinda yeni Apple Development sertifikasinin private key ile geldiginin dogrula"
  echo "9) DerivedData temizle"
  echo "10) Projeyi tekrar ac ve build al"
} > "$OUT_DIR/manual_steps.txt"

security find-identity -v -p codesigning > "$OUT_DIR/find_identity.txt" 2>&1 || true
security default-keychain > "$OUT_DIR/default_keychain.txt" 2>&1 || true
security find-certificate -a -c "Apple Worldwide Developer Relations" /Library/Keychains/System.keychain ~/Library/Keychains/login.keychain-db > "$OUT_DIR/wwdr.txt" 2>&1 || true

printf 'OUT_DIR=%s\n' "$OUT_DIR"
