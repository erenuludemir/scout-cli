#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"

echo "1) Package.swift exclude/sources/resources kararını doğrula"
echo "2) Xcode project reference ve build phase kirliliğini doğrula"
echo "3) WalletKit duplicate owner'ı tekilleştir"
echo "4) AppEnvironment/StorageService/SyncClient owner surface'ini sabitle"
echo "5) 11_next_actions.txt sırasını bu dört bulguya göre güncelle"
echo "6) Sonra generic code build çalıştır"
echo
echo "Code build komutu:"
echo "\"$ROOT/ops/repair_runbook/run_quantumai_codebuild_only.sh\""
