#!/bin/sh
# Release derlemesinde SimMode'u zorla kapat
sed -i '' 's/<key>SimMode<\/key><true\/>/<key>SimMode<\/key><false\/>/g' QuantumAIMobile/Resources/FeatureFlags.plist
echo "CI/CD: Live Mode aktif edildi."
