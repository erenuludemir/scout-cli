#!/bin/bash
set -e

echo "🍺 Installing QuantumAI via Homebrew..."

BREW_TAP_DIR=$(brew --repo)/Library/Taps/quantumai/homebrew-quantumai
mkdir -p "$BREW_TAP_DIR"
cp ./brew/quantumai.rb "$BREW_TAP_DIR/"

brew tap quantumai/quantumai
brew install quantumai

echo "✅ Installed via brew!"
