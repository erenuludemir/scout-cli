#!/bin/bash
set -e
echo "🚀 Starting QuantumAI Transfer System..."
echo "🖥 Launching GUI..."
open ./apps/QuantumAITransferGUI.app || echo "GUI failed"
echo "📡 Launching WebSocket Log Relay..."
open ./apps/WebSocketLogRelay.app || echo "WebSocket failed"
echo "🔐 Launching Vault Environment Manager..."
open ./apps/VaultProtectedEnv.app || echo "Vault failed"
echo "🧠 Launching AI Predictor..."
open ./apps/AITransferPredictor.app || echo "AI module failed"
echo "✅ All modules launched."
