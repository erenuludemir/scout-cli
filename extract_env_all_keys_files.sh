#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
OUT_DIR="$ROOT/_env_keys_exports_from_all_files"
mkdir -p "$OUT_DIR"
cd "$ROOT" || exit 1

FILES=(
  ".env.all_env_keys_unique"
  ".env.all_env_keys_only"
)

extract_one() {
  local f="$1"
  local out="$OUT_DIR/$(basename "$f").txt"
  printf '\n===== %s =====\n' "$f"
  if [ -f "$f" ]; then
    awk '
      /^[[:space:]]*$/ { next }
      { print }
    ' "$f" | tee "$out"
  else
    echo "DOSYA_YOK: $f" | tee "$out"
  fi
}

: > "$OUT_DIR/all_lines_combined.txt"
: > "$OUT_DIR/all_lines_unique.txt"

for f in "${FILES[@]}"; do
  extract_one "$f"
done

printf '\n===== BIRLESTIRILMIS TEK CIKTI =====\n'
for f in "${FILES[@]}"; do
  echo "### $f" | tee -a "$OUT_DIR/all_lines_combined.txt"
  if [ -f "$f" ]; then
    awk '
      /^[[:space:]]*$/ { next }
      { print }
    ' "$f" | tee -a "$OUT_DIR/all_lines_combined.txt"
  else
    echo "DOSYA_YOK" | tee -a "$OUT_DIR/all_lines_combined.txt"
  fi
  echo | tee -a "$OUT_DIR/all_lines_combined.txt"
done

awk '
  /^### / { next }
  /^DOSYA_YOK/ { next }
  /^[[:space:]]*$/ { next }
  !seen[$0]++ { print }
' "$OUT_DIR/all_lines_combined.txt" | tee "$OUT_DIR/all_lines_unique.txt"

printf '\n===== OZET =====\n'
ls -1 "$OUT_DIR"

printf '\n===== TEKIL SATIR SAYISI =====\n'
wc -l < "$OUT_DIR/all_lines_unique.txt"

printf '\n===== CIKTI KLASORU =====\n%s\n' "$OUT_DIR"
