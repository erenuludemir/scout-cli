#!/bin/sh
set -e

# 1. Swift Lint kontrolü (Kod kalitesi)
# 2. Gereksiz dosyaların temizlenmesi
echo "CI/CD: Proje derlemeye hazırlanıyor..."

# 3. FeatureFlags.plist kontrolü
if [ ! -f "QuantumAIMobile/Resources/FeatureFlags.plist" ]; then
  echo "HATA: FeatureFlags.plist eksik!"
  exit 1
fi
