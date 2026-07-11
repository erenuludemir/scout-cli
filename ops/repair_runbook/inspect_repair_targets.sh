#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
RUNBOOK_DIR="$ROOT/_reports/repair_runbook/20260401_172758"

printf '\n=== 02_package_scope.txt ===\n'
sed -n '1,240p' "$RUNBOOK_DIR/02_package_scope.txt"

printf '\n=== 03_xcodeproj_refs.txt ===\n'
sed -n '1,260p' "$RUNBOOK_DIR/03_xcodeproj_refs.txt"

printf '\n=== 05_wallet_duplicate_scan.txt ===\n'
sed -n '1,260p' "$RUNBOOK_DIR/05_wallet_duplicate_scan.txt"

printf '\n=== 06_owner_surface_scan.txt ===\n'
sed -n '1,260p' "$RUNBOOK_DIR/06_owner_surface_scan.txt"

printf '\n=== 11_next_actions.txt ===\n'
sed -n '1,200p' "$RUNBOOK_DIR/11_next_actions.txt"

printf '\n=== ACTIVE PACKAGE.SWIFT SNAPSHOT ===\n'
sed -n '1,220p' "$ROOT/ios/QuantumAIMobile/Package.swift"
