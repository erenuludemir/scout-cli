#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$PROJECT_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$PROJECT_DIR/_backups/compose_hardening_$TS"
LOG_DIR="$PROJECT_DIR/_logs/health/compose_hardening_$TS"
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

COMPOSE_FILE=""
for f in compose.yml docker-compose.yml compose.yaml docker-compose.yaml; do
  if [ -f "$PROJECT_DIR/$f" ]; then
    COMPOSE_FILE="$PROJECT_DIR/$f"
    break
  fi
done
[ -n "$COMPOSE_FILE" ] || { echo "COMPOSE_FILE_YOK:$PROJECT_DIR"; exit 1; }

PROJECT_NAME="${PROJECT_NAME:-quantumai-stack}"
OVERRIDE_FILE="$PROJECT_DIR/ops/compose.hardening.override.yml"
ENV_FILE="$PROJECT_DIR/ops/compose.hardening.env"
REPORT_FILE="$LOG_DIR/report.txt"
NETWORK_FIX_JSON="$LOG_DIR/docker_networks_bridge_only.json"
PORTS_FILE="$LOG_DIR/ports.txt"

cp -f "$COMPOSE_FILE" "$BACKUP_DIR/$(basename "$COMPOSE_FILE").bak"
[ -f "$PROJECT_DIR/compose.override.yml" ] && cp -f "$PROJECT_DIR/compose.override.yml" "$BACKUP_DIR/compose.override.yml.bak" || true
[ -f "$OVERRIDE_FILE" ] && cp -f "$OVERRIDE_FILE" "$BACKUP_DIR/compose.hardening.override.yml.bak" || true
[ -f "$ENV_FILE" ] && cp -f "$ENV_FILE" "$BACKUP_DIR/compose.hardening.env.bak" || true

docker context show > "$LOG_DIR/docker_context.txt" 2>&1 || true
docker info > "$LOG_DIR/docker_info.txt" 2>&1 || true
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}' > "$LOG_DIR/docker_ps_before.txt" 2>&1 || true
docker network ls --format '{{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}' | awk -F'\t' '$3!="null"{print $0}' > "$LOG_DIR/docker_network_ls_non_null.txt" 2>&1 || true
{
  echo "# BRIDGE_NETWORKS_ONLY"
  while IFS=$'\t' read -r nid nname ndriver nscope; do
    [ -n "${nid:-}" ] || continue
    docker network inspect "$nid" --format '{{json .}}' 2>/dev/null || true
  done < <(docker network ls --format '{{.ID}}\t{{.Name}}\t{{.Driver}}\t{{.Scope}}' | awk -F'\t' '$3=="bridge"{print $0}')
} > "$NETWORK_FIX_JSON"

port_in_use() {
  local p="$1"
  if lsof -nP -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

pick_port() {
  local preferred="$1"
  shift
  local candidates=("$preferred" "$@")
  local p
  for p in "${candidates[@]}"; do
    if ! port_in_use "$p"; then
      echo "$p"
      return 0
    fi
  done
  local base="$preferred"
  while :; do
    base="$((base+1))"
    if ! port_in_use "$base"; then
      echo "$base"
      return 0
    fi
  done
}

GRAFANA_HOST_PORT="$(pick_port 3000 3300 3301 4300 5300)"
PROMETHEUS_HOST_PORT="$(pick_port 9090 39090 39091 49090 59090)"
CADVISOR_HOST_PORT="$(pick_port 8080 38080 38081 48080 58080)"
METRICS_HOST_PORT="$(pick_port 9100 39100 39101 49100 59100)"

{
  echo "GRAFANA_HOST_PORT=$GRAFANA_HOST_PORT"
  echo "PROMETHEUS_HOST_PORT=$PROMETHEUS_HOST_PORT"
  echo "CADVISOR_HOST_PORT=$CADVISOR_HOST_PORT"
  echo "METRICS_HOST_PORT=$METRICS_HOST_PORT"
} | tee "$ENV_FILE" > "$PORTS_FILE"

SERVICES="$(docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" config --services 2>/dev/null || true)"
[ -n "$SERVICES" ] || { echo "SERVIS_LISTESI_ALINAMADI:$COMPOSE_FILE"; exit 1; }

has_service() {
  printf '%s\n' "$SERVICES" | grep -Fxq "$1"
}

append_block() {
  cat >> "$OVERRIDE_FILE"
}

: > "$OVERRIDE_FILE"
append_block <<'YAML'
name: quantumai-stack
x-qai-defaults: &qai-defaults
  restart: unless-stopped
  logging:
    driver: json-file
    options:
      max-size: "20m"
      max-file: "5"

networks:
  ops_isolated:
    driver: bridge
    internal: true

services:
YAML

add_generic_service() {
  local svc="$1"
  local mem_limit="$2"
  local mem_reservation="$3"
  local pids="$4"
  append_block <<YAML
  $svc:
    <<: *qai-defaults
    mem_limit: "$mem_limit"
    mem_reservation: "$mem_reservation"
    pids_limit: $pids
    labels:
      autoheal: "true"
YAML
}

add_http_service() {
  local svc="$1"
  local mem_limit="$2"
  local mem_reservation="$3"
  local pids="$4"
  local path="$5"
  local port="$6"
  append_block <<YAML
  $svc:
    <<: *qai-defaults
    mem_limit: "$mem_limit"
    mem_reservation: "$mem_reservation"
    pids_limit: $pids
    labels:
      autoheal: "true"
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "sh -ec 'if command -v curl >/dev/null 2>&1; then curl -fsS http://127.0.0.1:$port$path >/dev/null; elif command -v wget >/dev/null 2>&1; then wget -qO- http://127.0.0.1:$port$path >/dev/null; elif command -v nc >/dev/null 2>&1; then nc -z 127.0.0.1 $port; else exit 0; fi'"
        ]
      interval: 30s
      timeout: 8s
      retries: 5
      start_period: 40s
YAML
}

add_redis_service() {
  local svc="$1"
  append_block <<YAML
  $svc:
    <<: *qai-defaults
    mem_limit: "768m"
    mem_reservation: "256m"
    pids_limit: 256
    labels:
      autoheal: "true"
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "sh -ec 'if command -v redis-cli >/dev/null 2>&1; then redis-cli -h 127.0.0.1 ping | grep -q PONG; elif command -v nc >/dev/null 2>&1; then nc -z 127.0.0.1 6379; else exit 0; fi'"
        ]
      interval: 15s
      timeout: 5s
      retries: 10
      start_period: 20s
YAML
}

add_pg_service() {
  local svc="$1"
  append_block <<YAML
  $svc:
    <<: *qai-defaults
    mem_limit: "1536m"
    mem_reservation: "512m"
    pids_limit: 512
    labels:
      autoheal: "true"
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "sh -ec 'if command -v pg_isready >/dev/null 2>&1; then pg_isready -h 127.0.0.1 -p 5432 -U \${POSTGRES_USER:-postgres}; elif command -v nc >/dev/null 2>&1; then nc -z 127.0.0.1 5432; else exit 0; fi'"
        ]
      interval: 15s
      timeout: 5s
      retries: 10
      start_period: 25s
YAML
}

add_redpanda_service() {
  local svc="$1"
  append_block <<YAML
  $svc:
    <<: *qai-defaults
    mem_limit: "2048m"
    mem_reservation: "1024m"
    pids_limit: 512
    labels:
      autoheal: "true"
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "sh -ec 'if command -v rpk >/dev/null 2>&1; then rpk cluster health >/dev/null 2>&1; elif command -v nc >/dev/null 2>&1; then nc -z 127.0.0.1 9092; else exit 0; fi'"
        ]
      interval: 20s
      timeout: 10s
      retries: 10
      start_period: 40s
YAML
}

for svc in gateway dex rosettaai quantumai-usdt quantumai-usdt-apps quantumai-usdt-v2 metrics managerai managerai-broker managerai-guard gli-mainnet gli-sepolia gli-container mcai-api mcai-feeder mcai-risk mcai-sim mcai-router mcai-small-agg mcai-trade-engine mcai-large-exec demo-app-qai; do
  if has_service "$svc"; then
    case "$svc" in
      gateway) add_http_service "$svc" "1024m" "256m" 256 "/health" "5000" ;;
      dex) add_http_service "$svc" "1024m" "256m" 256 "/health" "8000" ;;
      rosettaai) add_http_service "$svc" "1536m" "512m" 384 "/health" "8000" ;;
      quantumai-usdt) add_http_service "$svc" "768m" "256m" 256 "/health" "5000" ;;
      quantumai-usdt-apps) add_http_service "$svc" "768m" "256m" 256 "/health" "5000" ;;
      quantumai-usdt-v2) add_http_service "$svc" "768m" "256m" 256 "/health" "5000" ;;
      metrics) add_http_service "$svc" "512m" "128m" 128 "/health" "9100" ;;
      managerai) add_http_service "$svc" "1024m" "256m" 256 "/health" "8080" ;;
      managerai-broker) add_generic_service "$svc" "512m" "128m" 128 ;;
      managerai-guard) add_generic_service "$svc" "512m" "128m" 128 ;;
      gli-mainnet) add_http_service "$svc" "768m" "256m" 256 "/" "5000" ;;
      gli-sepolia) add_http_service "$svc" "768m" "256m" 256 "/" "5000" ;;
      gli-container) add_http_service "$svc" "768m" "256m" 256 "/" "5000" ;;
      mcai-api) add_http_service "$svc" "1024m" "256m" 256 "/health" "8000" ;;
      mcai-feeder) add_generic_service "$svc" "1024m" "256m" 256 ;;
      mcai-risk) add_generic_service "$svc" "1024m" "256m" 256 ;;
      mcai-sim) add_generic_service "$svc" "1024m" "256m" 256 ;;
      mcai-router) add_generic_service "$svc" "1024m" "256m" 256 ;;
      mcai-small-agg) add_generic_service "$svc" "1024m" "256m" 256 ;;
      mcai-trade-engine) add_generic_service "$svc" "1536m" "512m" 384 ;;
      mcai-large-exec) add_generic_service "$svc" "1536m" "512m" 384 ;;
      demo-app-qai) add_http_service "$svc" "768m" "256m" 256 "/health" "8000" ;;
    esac
  fi
done

if has_service "redis"; then
  add_redis_service "redis"
fi

if has_service "mcai-redis"; then
  add_redis_service "mcai-redis"
fi

if has_service "postgres"; then
  add_pg_service "postgres"
fi

if has_service "mcai-postgres"; then
  add_pg_service "mcai-postgres"
fi

if has_service "redpanda"; then
  add_redpanda_service "redpanda"
fi

if has_service "mcai-redpanda"; then
  add_redpanda_service "mcai-redpanda"
fi

if has_service "prometheus"; then
append_block <<YAML
  prometheus:
    <<: *qai-defaults
    mem_limit: "1024m"
    mem_reservation: "256m"
    pids_limit: 256
    ports:
      - "127.0.0.1:${PROMETHEUS_HOST_PORT}:9090"
    labels:
      autoheal: "false"
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "sh -ec 'if command -v wget >/dev/null 2>&1; then wget -qO- http://127.0.0.1:9090/-/healthy >/dev/null; elif command -v curl >/dev/null 2>&1; then curl -fsS http://127.0.0.1:9090/-/healthy >/dev/null; elif command -v nc >/dev/null 2>&1; then nc -z 127.0.0.1 9090; else exit 0; fi'"
        ]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 30s
YAML
fi

if has_service "grafana"; then
append_block <<YAML
  grafana:
    <<: *qai-defaults
    mem_limit: "1024m"
    mem_reservation: "256m"
    pids_limit: 256
    ports:
      - "127.0.0.1:${GRAFANA_HOST_PORT}:3000"
    labels:
      autoheal: "false"
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "sh -ec 'if command -v wget >/dev/null 2>&1; then wget -qO- http://127.0.0.1:3000/api/health >/dev/null; elif command -v curl >/dev/null 2>&1; then curl -fsS http://127.0.0.1:3000/api/health >/dev/null; elif command -v nc >/dev/null 2>&1; then nc -z 127.0.0.1 3000; else exit 0; fi'"
        ]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 40s
YAML
fi

if has_service "cadvisor"; then
append_block <<YAML
  cadvisor:
    <<: *qai-defaults
    mem_limit: "384m"
    mem_reservation: "128m"
    pids_limit: 128
    ports:
      - "127.0.0.1:${CADVISOR_HOST_PORT}:8080"
    networks:
      - ops_isolated
    labels:
      autoheal: "false"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker:/var/lib/docker:ro
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "sh -ec 'if command -v wget >/dev/null 2>&1; then wget -qO- http://127.0.0.1:8080/healthz >/dev/null; elif command -v curl >/dev/null 2>&1; then curl -fsS http://127.0.0.1:8080/healthz >/dev/null; elif command -v nc >/dev/null 2>&1; then nc -z 127.0.0.1 8080; else exit 0; fi'"
        ]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 20s
YAML
fi

if has_service "autoheal"; then
append_block <<'YAML'
  autoheal:
    <<: *qai-defaults
    mem_limit: "256m"
    mem_reservation: "64m"
    pids_limit: 128
    networks:
      - ops_isolated
    environment:
      AUTOHEAL_CONTAINER_LABEL: autoheal
      AUTOHEAL_INTERVAL: "15"
      AUTOHEAL_START_PERIOD: "60"
      CURL_TIMEOUT: "10"
      DOCKER_SOCK: /var/run/docker.sock
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    labels:
      autoheal: "false"
YAML
fi

if has_service "watchtower"; then
append_block <<'YAML'
  watchtower:
    <<: *qai-defaults
    mem_limit: "256m"
    mem_reservation: "64m"
    pids_limit: 128
    labels:
      autoheal: "false"
YAML
fi

docker compose -f "$COMPOSE_FILE" -f "$OVERRIDE_FILE" -p "$PROJECT_NAME" config > "$LOG_DIR/compose_merged.yaml"

if ! grep -q '/var/run/docker.sock:/var/run/docker.sock' "$OVERRIDE_FILE"; then
  echo "UYARI: autoheal override socket mount eklenmedi" >> "$REPORT_FILE"
fi

{
  echo "PROJECT_DIR=$PROJECT_DIR"
  echo "COMPOSE_FILE=$COMPOSE_FILE"
  echo "OVERRIDE_FILE=$OVERRIDE_FILE"
  echo "PROJECT_NAME=$PROJECT_NAME"
  echo "GRAFANA_HOST_PORT=$GRAFANA_HOST_PORT"
  echo "PROMETHEUS_HOST_PORT=$PROMETHEUS_HOST_PORT"
  echo "CADVISOR_HOST_PORT=$CADVISOR_HOST_PORT"
  echo "METRICS_HOST_PORT=$METRICS_HOST_PORT"
  echo "SERVICES_START"
  printf '%s\n' "$SERVICES"
  echo "SERVICES_END"
} > "$REPORT_FILE"

docker compose -f "$COMPOSE_FILE" -f "$OVERRIDE_FILE" -p "$PROJECT_NAME" down --remove-orphans > "$LOG_DIR/compose_down.log" 2>&1 || true
docker compose -f "$COMPOSE_FILE" -f "$OVERRIDE_FILE" -p "$PROJECT_NAME" up -d --remove-orphans > "$LOG_DIR/compose_up.log" 2>&1
sleep 8
docker compose -f "$COMPOSE_FILE" -f "$OVERRIDE_FILE" -p "$PROJECT_NAME" ps > "$LOG_DIR/compose_ps_after.txt" 2>&1 || true
docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}' > "$LOG_DIR/docker_ps_after.txt" 2>&1 || true

check_http() {
  local url="$1"
  local out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsS "$url" > "$out" 2>"$out.err" || true
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$url" > "$out" 2>"$out.err" || true
  fi
}

[ -n "${GRAFANA_HOST_PORT:-}" ] && check_http "http://127.0.0.1:${GRAFANA_HOST_PORT}/api/health" "$LOG_DIR/grafana_health.json"
[ -n "${PROMETHEUS_HOST_PORT:-}" ] && check_http "http://127.0.0.1:${PROMETHEUS_HOST_PORT}/-/healthy" "$LOG_DIR/prometheus_health.txt"
[ -n "${CADVISOR_HOST_PORT:-}" ] && check_http "http://127.0.0.1:${CADVISOR_HOST_PORT}/healthz" "$LOG_DIR/cadvisor_health.txt"

echo "TAMAMLANDI:$LOG_DIR"
