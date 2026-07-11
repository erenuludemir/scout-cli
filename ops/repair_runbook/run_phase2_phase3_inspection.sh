#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
RUNBOOK_DIR="$ROOT/_reports/repair_runbook/20260401_172758"
OUT="$ROOT/_reports/repair_runbook/focused_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUT"

echo "=== 03_xcodeproj_refs.txt ===" | tee "$OUT/01_xcodeproj_refs.review.txt"
sed -n '1,260p' "$RUNBOOK_DIR/03_xcodeproj_refs.txt" | tee -a "$OUT/01_xcodeproj_refs.review.txt"

echo | tee -a "$OUT/01_xcodeproj_refs.review.txt"
echo "=== Host/App pbxproj suspicious refs ===" | tee -a "$OUT/01_xcodeproj_refs.review.txt"
grep -nE '\.bak|\.orig|\.tmp|\.disabled|legacy|snapshot|log|RootView|HostRootView|PerformanceChart|AuditReportGenerator|IntegrityChecker|SyncClient' \
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobileHost.xcodeproj/project.pbxproj" \
  "$ROOT/ios/QuantumAIMobileApp/QuantumAIMobileApp.xcodeproj/project.pbxproj" \
  | tee "$OUT/02_pbx_suspicious_matches.txt" || true

echo "=== 05_wallet_duplicate_scan.txt ===" | tee "$OUT/03_wallet_duplicate.review.txt"
sed -n '1,260p' "$RUNBOOK_DIR/05_wallet_duplicate_scan.txt" | tee -a "$OUT/03_wallet_duplicate.review.txt"

echo | tee -a "$OUT/03_wallet_duplicate.review.txt"
echo "=== Wallet canonical owner scan ===" | tee -a "$OUT/03_wallet_duplicate.review.txt"
grep -RInE 'struct RawTransaction|func signTRON\(txHash:|init\(chainId: Int, nonce: UInt64, to: String, value: Decimal, data: Data\)' \
  "$ROOT/ios/QuantumAIMobile/QuantumAIMobile" \
  | tee "$OUT/04_wallet_canonical_hits.txt" || true

echo "=== 06_owner_surface_scan.txt ===" | tee "$OUT/05_owner_surface.review.txt"
sed -n '1,340p' "$RUNBOOK_DIR/06_owner_surface_scan.txt" | tee -a "$OUT/05_owner_surface.review.txt"

echo | tee -a "$OUT/05_owner_surface.review.txt"
echo "=== Canonical owner assertions ===" | tee -a "$OUT/05_owner_surface.review.txt"
{
  echo "[watchlist owner]"
  grep -RIn 'public let watchlist: WatchlistService\|let watchlist = WatchlistService()\|self.watchlist = watchlist' \
    "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/AppShell/AppEnvironment.swift" || true
  echo
  echo "[outbox owner]"
  grep -RIn '@Published public private(set) var outbox: \[Order\] = \[\]\|public func queueForBroadcast(_ order: Order)\|public func appendAudit(_ record: AuditRecord)\|public func append(order: Order) -> Bool' \
    "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/StorageKit/StorageService.swift" || true
  echo
  echo "[flushOutbox owner]"
  grep -RIn 'public func flushOutbox() async' \
    "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/SettingsKit/SyncClient.swift" \
    "$ROOT/ios/QuantumAIMobile/QuantumAIMobile/SyncKit" || true
} | tee "$OUT/06_owner_assertions.txt"

echo "=== 11_next_actions.txt ===" | tee "$OUT/07_next_actions.review.txt"
sed -n '1,220p' "$RUNBOOK_DIR/11_next_actions.txt" | tee -a "$OUT/07_next_actions.review.txt"

cat > "$OUT/08_decision_summary.txt" <<'EOF'
KARAR KURALI
1) 03_xcodeproj_refs temizse pbxproj tarafında yalnız gerçek swift kaynaklar kalmış olmalı.
2) 05_wallet_duplicate_scan tek owner gösteriyorsa RawTransaction/signTRON canonical owner WalletService.swift olarak sabit.
3) 06_owner_surface_scan sonuçlarına göre:
   - watchlist owner = AppEnvironment
   - outbox/append/appendAudit/queueForBroadcast owner = StorageService
   - flushOutbox owner = SettingsKit/SyncClient
4) PerformanceChart.swift fiziksel olarak var ama Package.swift exclude içinde; buna rağmen referans varsa bu dosya kayıp değil scope mismatch.
5) Sonraki build code-only alınmalı, signing yok.
EOF

printf '%s\n' "$OUT"
