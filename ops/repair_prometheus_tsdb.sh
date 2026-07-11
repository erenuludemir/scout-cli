#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
COMPOSE_MAIN="$REPO/compose.yml"
COMPOSE_OVERRIDE="$REPO/ops/compose.hardening.override.yml"
PROJECT="quantumai-stack"
TS="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="$REPO/_logs/hardening"
BACKUP_DIR="$REPO/_backups/prometheus_tsdb_$TS"
mkdir -p "$LOG_DIR" "$BACKUP_DIR"

PROM_CONTAINER="$(docker ps -a --format '{{.Names}}' | awk '$0=="quantumai-stack-prometheus-1"{print; exit}')"
if [ -z "$PROM_CONTAINER" ]; then
  PROM_CONTAINER="$(docker compose -f "$COMPOSE_MAIN" -f "$COMPOSE_OVERRIDE" -p "$PROJECT" ps -q prometheus | xargs -I{} docker inspect --format '{{.Name}}' {} 2>/dev/null | sed 's#^/##' | head -n1 || true)"
fi
if [ -z "$PROM_CONTAINER" ]; then
  echo "PROMETHEUS_CONTAINER_YOK"
  exit 1
fi

MOUNT_SRC="$(docker inspect "$PROM_CONTAINER" --format '{{range .Mounts}}{{if eq .Destination "/prometheus"}}{{.Source}}{{end}}{{end}}')"
if [ -z "$MOUNT_SRC" ]; then
  echo "PROMETHEUS_MOUNT_YOK"
  exit 1
fi

echo "PROM_CONTAINER=$PROM_CONTAINER" | tee "$LOG_DIR/prometheus_repair_$TS.log"
echo "PROM_SRC=$MOUNT_SRC" | tee -a "$LOG_DIR/prometheus_repair_$TS.log"

docker compose -f "$COMPOSE_MAIN" -f "$COMPOSE_OVERRIDE" -p "$PROJECT" stop prometheus | tee -a "$LOG_DIR/prometheus_repair_$TS.log"

if [ -d "$MOUNT_SRC" ]; then
  mkdir -p "$BACKUP_DIR"
  if [ "$(find "$MOUNT_SRC" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')" != "0" ]; then
    tar -C "$MOUNT_SRC" -czf "$BACKUP_DIR/prometheus_data_before_repair.tar.gz" . || true
  fi
  rm -rf "$MOUNT_SRC/chunks_head" "$MOUNT_SRC/wal"
  mkdir -p "$MOUNT_SRC/chunks_head" "$MOUNT_SRC/wal"
fi

docker compose -f "$COMPOSE_MAIN" -f "$COMPOSE_OVERRIDE" -p "$PROJECT" up -d prometheus | tee -a "$LOG_DIR/prometheus_repair_$TS.log"
sleep 8
curl -fsS http://127.0.0.1:9090/-/ready | tee -a "$LOG_DIR/prometheus_repair_$TS.log"
echo | tee -a "$LOG_DIR/prometheus_repair_$TS.log"
echo "PROMETHEUS_REPAIR_OK BACKUP=$BACKUP_DIR/prometheus_data_before_repair.tar.gz" | tee -a "$LOG_DIR/prometheus_repair_$TS.log"
