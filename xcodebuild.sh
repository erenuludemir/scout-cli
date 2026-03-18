#!/bin/bash
set -e

echo "🛠 Building QuantumAI GUI from Xcode project..."

xcodebuild -project ./xcodeproj/QuantumAIApp.xcodeproj \
           -scheme QuantumAIApp \
           -configuration Release \
           -derivedDataPath ./xcodeproj/build

echo "✅ Build complete. App output is in ./xcodeproj/build/Build/Products/Release"
