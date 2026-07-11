#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
OUT_DIR="$ROOT/_env_keys_exports"
mkdir -p "$OUT_DIR"
cd "$ROOT" || exit 1

FILES=(
  ".env"
  ".env.auto"
  ".env.example"
  ".env.hardening"
  ".env.kazan"
  ".env.local"
  ".env.runtime"
  ".env.runtime.fix"
  ".env.secrets"
  ".env.token_factory.example"
  ".envrc"
  ".envrc.disabled"
)

extract_one() {
  local f="$1"
  local out="$OUT_DIR/$(basename "$f").keys.only"
  printf '\n===== %s =====\n' "$f"
  if [ -f "$f" ]; then
    awk '
      /^[[:space:]]*#/ { next }
      /^[[:space:]]*$/ { next }
      /^[[:space:]]*export[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=/ {
        line=$0
        sub(/^[[:space:]]*export[[:space:]]+/, "", line)
        sub(/=.*/, "=", line)
        print line
        next
      }
      /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=/ {
        line=$0
        sub(/^[[:space:]]*/, "", line)
        sub(/=.*/, "=", line)
        print line
        next
      }
    ' "$f" | tee "$out"
  else
    echo "DOSYA_YOK: $f" | tee "$out"
  fi
}

: > "$OUT_DIR/all_env_keys_only.txt"
: > "$OUT_DIR/all_env_keys_unique.txt"

for f in "${FILES[@]}"; do
  extract_one "$f"
done

printf '\n===== BIRLESTIRILMIS TEK CIKTI =====\n'
for f in "${FILES[@]}"; do
  echo "### $f" | tee -a "$OUT_DIR/all_env_keys_only.txt"
  if [ -f "$f" ]; then
    awk '
      /^[[:space:]]*#/ { next }
      /^[[:space:]]*$/ { next }
      /^[[:space:]]*export[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=/ {
        line=$0
        sub(/^[[:space:]]*export[[:space:]]+/, "", line)
        sub(/=.*/, "=", line)
        print line
        next
      }
      /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=/ {
        line=$0
        sub(/^[[:space:]]*/, "", line)
        sub(/=.*/, "=", line)
        print line
        next
      }
    ' "$f" | tee -a "$OUT_DIR/all_env_keys_only.txt"
  else
    echo "DOSYA_YOK" | tee -a "$OUT_DIR/all_env_keys_only.txt"
  fi
  echo | tee -a "$OUT_DIR/all_env_keys_only.txt"
done

awk '
  /^### / { next }
  /^DOSYA_YOK/ { next }
  /^[A-Za-z_][A-Za-z0-9_]*=$/ {
    if (!seen[$0]++) print
  }
' "$OUT_DIR/all_env_keys_only.txt" | tee "$OUT_DIR/all_env_keys_unique.txt"

printf '\n===== OZET =====\n'
ls -1 "$OUT_DIR"

printf '\n===== TEKIL ANAHTAR SAYISI =====\n'
wc -l < "$OUT_DIR/all_env_keys_unique.txt"

printf '\n===== CIKTI KLASORU =====\n%s\n' "$OUT_DIR"
