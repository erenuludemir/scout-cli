#!/bin/bash

echo "🚀 Xvfb başlatılıyor..."
Xvfb :99 -screen 0 1024x768x16 &

echo "🖥 QuantumAI Transfer GUI başlatılıyor..."
open /QuantumAI-Transfer-System/QuantumAITransferGUI.app &

echo "📡 WebSocket log yayıncısı başlatılıyor..."
open /QuantumAI-Transfer-System/WebSocketLogRelay.app &

echo "🔐 Vault ortam yöneticisi başlatılıyor..."
open /QuantumAI-Transfer-System/VaultProtectedEnv.app &

echo "🧠 AI tahmin modeli başlatılıyor..."
open /QuantumAI-Transfer-System/AITransferPredictor.app &

wait
