#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
ZIP_PATH="${1:-$ROOT/log.zip}"
OUT_DIR="${2:-$ROOT/_reports/log_repair/latest}"

mkdir -p "$ROOT/_reports/log_repair"

python3 "$ROOT/ops/log_repair/qai_log_archive_repair.py" --zip "$ZIP_PATH" --out "$OUT_DIR"

echo "OK: $OUT_DIR/reports/manifest.json"
echo "OK: $OUT_DIR/reports/batch_a.md"
echo "OK: $OUT_DIR/reports/batch_b.md"
echo "OK: $OUT_DIR/reports/batch_c.md"
echo "OK: $OUT_DIR/reports/batch_d.md"
echo "OK: $OUT_DIR/reports/top10_read_order.md"
echo "OK: $OUT_DIR/reports/network_noise.md"
