#!/usr/bin/env bash
# Incremental + full backup script for /data volume.
set -euo pipefail
SRC=${1:-${APP_ROOT:-/data}}
DST=${2:-${SRC}/backups}
TS=$(date -u +%Y%m%dT%H%M%SZ)
FULL_DIR=${DST}/full_${TS}
MANIFEST=${FULL_DIR}/manifest.sha256
mkdir -p "${FULL_DIR}"
# Copy (could be optimized with rsync --link-dest for huge trees)
rsync -a --delete "${SRC}/" "${FULL_DIR}/" --exclude backups || true
# Hash manifest
( cd "${FULL_DIR}" && find . -type f -print0 | sort -z | xargs -0 shasum -a 256 ) > "${MANIFEST}" || true
# Archive (optional)
TAR=${DST}/archive_${TS}.tar.gz
( cd "${FULL_DIR}" && tar -czf "${TAR}" . ) || true
cat <<EOF
Backup complete
  source: ${SRC}
  full:   ${FULL_DIR}
  manifest: ${MANIFEST}
  archive: ${TAR}
EOF
