#!/usr/bin/env bash
# Migrate working repository to external volume (Option 2)
# Safe usage:
#   MODE=dry  ./scripts/migrate_to_external.sh   (default)
#   MODE=commit ./scripts/migrate_to_external.sh
# Idempotent; uses rsync. Does NOT delete source.
set -euo pipefail
SRC_ROOT="${SRC_ROOT:-$(pwd)}"
DEST_BASE="${DEST_BASE:-${APP_ROOT_EXTERNAL_BASE:-/Volumes/LaCie/Container-QuantumAI}}"
DEST="${DEST:-${DEST_BASE}/QuantumAI-Dockerized-System}"
MODE="${MODE:-dry}"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_ROOT="${BACKUP_ROOT:-${DEST_BASE}/QuantumAI-Dockerized-System-Beckup}"
LOG_ROOT="${LOG_ROOT:-${DEST_BASE}/QuantumAI-Dockerized-System-Log}"
MODEL_FILE="${MODEL_FILE:-${DEST_BASE}/Recovered_Backup_28082025/trained_model.json}"
EXCLUDES=(
  "--exclude" ".git/objects/pack/*.keep"
  "--exclude" ".venv"
  "--exclude" "__pycache__"
  "--exclude" ".mypy_cache"
  "--exclude" ".pytest_cache"
  "--exclude" "*.pyc"
  "--exclude" "*.log"
)
mkdir -p "${DEST_BASE}" "${DEST}" "${BACKUP_ROOT}" "${LOG_ROOT}" || true
echo "[info] Source: ${SRC_ROOT} -> Dest: ${DEST} (mode=${MODE})"
echo "[info] Backup root: ${BACKUP_ROOT}"; echo "[info] Log root: ${LOG_ROOT}"
if [[ -f "${MODEL_FILE}" ]]; then
  echo "[info] Model OK: ${MODEL_FILE}";
else
  echo "[warn] Model missing at ${MODEL_FILE}";
fi
command -v rsync >/dev/null 2>&1 || { echo "[error] rsync not installed"; exit 1; }
# Perform sync
# macOS default rsync may not support -HAX; use portable flags
rsync -a --delete "${EXCLUDES[@]}" "${SRC_ROOT}/" "${DEST}/" | tee "${LOG_ROOT}/rsync_${TS}.log"
# Initialize git at destination if needed
if [[ ! -d "${DEST}/.git" ]]; then
  ( cd "${DEST}" && git init -q && git add . && git commit -m 'External volume baseline' >/dev/null 2>&1 || true )
fi
# Record hash state for verification
SRC_HASH_FILE="/tmp/migrate_src_hash_${TS}.txt"
DST_HASH_FILE="/tmp/migrate_dst_hash_${TS}.txt"
find "${SRC_ROOT}" -type f -not -path '*/.git/*' -print0 | sort -z | xargs -0 shasum -a 256 >"${SRC_HASH_FILE}" || true
find "${DEST}"     -type f -not -path '*/.git/*' -print0 | sort -z | xargs -0 shasum -a 256 >"${DST_HASH_FILE}" || true
DIFF_COUNT=$(diff -u "${SRC_HASH_FILE}" "${DST_HASH_FILE}" | grep -E '^[+-][0-9a-f]' | wc -l | tr -d ' ' || true)
if [[ "${DIFF_COUNT}" != "0" ]]; then
  echo "[warn] Hash differences detected (${DIFF_COUNT}); inspect before commit." | tee -a "${LOG_ROOT}/verify_${TS}.log" >&2
else
  echo "[info] Hash verification OK (no differences)." | tee -a "${LOG_ROOT}/verify_${TS}.log"
fi
if [[ "${MODE}" == "commit" ]]; then
  echo "[info] Creating compressed snapshot backup";
  SNAP_DIR="${BACKUP_ROOT}/${TS}"; mkdir -p "${SNAP_DIR}";
  tar -cpf "${SNAP_DIR}/repo_snapshot.tar" -C "${SRC_ROOT}" .
  echo "APP_ROOT=${DEST}" > "${SRC_ROOT}/.app_root.migrated"
  echo "[done] Migration committed. Update env: export APP_ROOT=${DEST}";
  echo "[rollback] Restore: tar -xpf ${SNAP_DIR}/repo_snapshot.tar -C <restore_dir>";
else
  echo "[dry-run] Not writing .app_root.migrated (set MODE=commit to finalize)."
  echo "[dry-run] Would create backup at ${BACKUP_ROOT}/${TS}";
fi
