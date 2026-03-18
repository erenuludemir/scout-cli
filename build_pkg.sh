#!/bin/bash
set -e

APP_DIR="./apps"
PKG_OUTPUT="./pkg/QuantumAIInstaller.pkg"

echo "📦 Building macOS .pkg installer..."
pkgbuild --identifier "com.quantumai.transfer" \
         --version "1.0.0" \
         --install-location "/Applications" \
         --component "$APP_DIR/QuantumAITransferGUI.app" \
         "$PKG_OUTPUT"

echo "✅ Installer created at: $PKG_OUTPUT"
