#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
IOS_ROOT="$REPO/ios/QuantumAIMobile"
COMPOSE_FILE="$REPO/compose.yml"
LOG_DIR="$REPO/_logs/ios_megapipeline"
BACKUP_DIR="$REPO/_backups/ios_megapipeline"
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

PRECHECK_LOG="$LOG_DIR/${TS}_compose_precheck.log"
POSTCHECK_LOG="$LOG_DIR/${TS}_compose_postcheck.log"
UP_LOG="$LOG_DIR/${TS}_compose_up.log"
REPORT_LOG="$LOG_DIR/${TS}_inject_report.log"
BACKUP_FILE="$BACKUP_DIR/compose.yml.${TS}.bak"

cp "$COMPOSE_FILE" "$BACKUP_FILE"

docker compose -f "$COMPOSE_FILE" -p quantumai-stack config > "$PRECHECK_LOG" 2>&1

python3 - "$COMPOSE_FILE" "$IOS_ROOT" <<'PY'
from pathlib import Path
import sys

compose = Path(sys.argv[1])
ios_root = sys.argv[2]
text = compose.read_text(encoding="utf-8")

service_block = f"""  qai-ios-bundle:
    image: alpine:3.20
    container_name: qai-ios-bundle
    command:
      - sh
      - -lc
      - while true; do sleep 3600; done
    volumes:
      - "{ios_root}:/srv/qai_ios:ro"
    restart: unless-stopped
    labels:
      qai.service: "qai-ios-bundle"
      qai.role: "mobile-bundle"
      autoheal: "false"
    healthcheck:
      test:
        - CMD-SHELL
        - test -d /srv/qai_ios
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 5s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

"""

if "\n  qai-ios-bundle:\n" not in text and not text.startswith("  qai-ios-bundle:\n"):
    if "services:\n" in text:
        text = text.replace("services:\n", "services:\n" + service_block, 1)
    else:
        text = "services:\n" + service_block + "\n" + text

compose.write_text(text, encoding="utf-8")
print("IOS_BUNDLE_SERVICE_READY")
PY

if ! docker compose -f "$COMPOSE_FILE" -p quantumai-stack config > "$POSTCHECK_LOG" 2>&1; then
  cp "$BACKUP_FILE" "$COMPOSE_FILE"
  echo "ROLLBACK=APPLIED" | tee "$REPORT_LOG"
  echo "BACKUP_FILE=$BACKUP_FILE" | tee -a "$REPORT_LOG"
  echo "PRECHECK_LOG=$PRECHECK_LOG" | tee -a "$REPORT_LOG"
  echo "POSTCHECK_LOG=$POSTCHECK_LOG" | tee -a "$REPORT_LOG"
  exit 1
fi

docker compose -f "$COMPOSE_FILE" -p quantumai-stack up -d qai-ios-bundle > "$UP_LOG" 2>&1

{
  echo "IOS_ROOT=$IOS_ROOT"
  echo "BACKUP_FILE=$BACKUP_FILE"
  echo "PRECHECK_LOG=$PRECHECK_LOG"
  echo "POSTCHECK_LOG=$POSTCHECK_LOG"
  echo "UP_LOG=$UP_LOG"
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'qai-ios-bundle|NAME' || true
} | tee "$REPORT_LOG"
