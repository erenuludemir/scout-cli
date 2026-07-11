#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(pwd)"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="${ROOT_DIR}/_backups/runtime_fix_${TS}"
mkdir -p "${BACKUP_DIR}"

pick_compose_file() {
  local f
  for f in "compose.yml" "docker-compose.yml" "docker-compose.base.yml" "compose.master.yml"; do
    [ -f "${ROOT_DIR}/${f}" ] && { printf '%s\n' "${ROOT_DIR}/${f}"; return 0; }
  done
  return 1
}

BASE_COMPOSE="$(pick_compose_file || true)"
[ -n "${BASE_COMPOSE}" ] || { echo "COMPOSE_FILE_YOK"; exit 1; }

OVERRIDE_FILE="${ROOT_DIR}/compose.runtime.fix.yml"
ENV_FILE="${ROOT_DIR}/.env.runtime.fix"

cp -f "${BASE_COMPOSE}" "${BACKUP_DIR}/$(basename "${BASE_COMPOSE}")"
[ -f "${ROOT_DIR}/compose.override.yml" ] && cp -f "${ROOT_DIR}/compose.override.yml" "${BACKUP_DIR}/compose.override.yml"
[ -f "${ROOT_DIR}/docker-compose.override.yml" ] && cp -f "${ROOT_DIR}/docker-compose.override.yml" "${BACKUP_DIR}/docker-compose.override.yml"
[ -f "${OVERRIDE_FILE}" ] && cp -f "${OVERRIDE_FILE}" "${BACKUP_DIR}/compose.runtime.fix.yml"
[ -f "${ENV_FILE}" ] && cp -f "${ENV_FILE}" "${BACKUP_DIR}/.env.runtime.fix"

cat > "${ENV_FILE}" <<'ENV'
GRAFANA_HOST_PORT=13000
PROMETHEUS_HOST_PORT=19090
CADVISOR_HOST_PORT=18080
AUTOHEAL_INTERVAL=15
AUTOHEAL_START_PERIOD=120
ENV

mapfile -t SERVICES < <(docker compose -f "${BASE_COMPOSE}" --env-file "${ENV_FILE}" config --services)

cat > "${OVERRIDE_FILE}" <<'YAML'
services:
YAML

append_block() {
  cat >> "${OVERRIDE_FILE}"
}

for svc in "${SERVICES[@]}"; do
  case "${svc}" in
    *cadvisor*)
      append_block <<YAML
  ${svc}:
    image: gcr.io/cadvisor/cadvisor:v0.49.2
    restart: unless-stopped
    mem_limit: 256m
    mem_reservation: 128m
    cpus: "0.50"
    privileged: false
    read_only: true
    ports:
      - "\${CADVISOR_HOST_PORT:-18080}:8080"
    command:
      - --docker_only=true
      - --housekeeping_interval=30s
      - --max_housekeeping_interval=35s
      - --store_container_labels=false
      - --disable_metrics=advtcp,cpu_topology,cpuset,disk,hugetlb,memory_numa,network_tcp,network_udp,percpu,process,referenced_memory,resctrl,sched,tcp,udp
    volumes:
      - /:/rootfs:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /sys:/sys:ro
    networks:
      - ops_isolated
    healthcheck:
      test: ["CMD-SHELL","wget -qO- http://127.0.0.1:8080/healthz >/dev/null 2>&1 || curl -fsS http://127.0.0.1:8080/healthz >/dev/null 2>&1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 20s
    tmpfs:
      - /tmp
YAML
      ;;
    autoheal|*autoheal*)
      append_block <<YAML
  ${svc}:
    image: willfarrell/autoheal:latest
    restart: unless-stopped
    mem_limit: 128m
    mem_reservation: 64m
    cpus: "0.25"
    read_only: true
    environment:
      AUTOHEAL_CONTAINER_LABEL: all
      AUTOHEAL_INTERVAL: \${AUTOHEAL_INTERVAL:-15}
      AUTOHEAL_START_PERIOD: \${AUTOHEAL_START_PERIOD:-120}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - ops_isolated
    healthcheck:
      test: ["CMD-SHELL","test -S /var/run/docker.sock"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 10s
    tmpfs:
      - /tmp
YAML
      ;;
    *grafana*)
      append_block <<YAML
  ${svc}:
    restart: unless-stopped
    mem_limit: 768m
    mem_reservation: 256m
    cpus: "1.00"
    ports:
      - "\${GRAFANA_HOST_PORT:-13000}:3000"
    labels:
      autoheal: "true"
    healthcheck:
      test: ["CMD-SHELL","wget -qO- http://127.0.0.1:3000/api/health >/dev/null 2>&1 || curl -fsS http://127.0.0.1:3000/api/health >/dev/null 2>&1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
YAML
      ;;
    *prometheus*)
      append_block <<YAML
  ${svc}:
    restart: unless-stopped
    mem_limit: 1024m
    mem_reservation: 384m
    cpus: "1.00"
    ports:
      - "\${PROMETHEUS_HOST_PORT:-19090}:9090"
    labels:
      autoheal: "true"
    healthcheck:
      test: ["CMD-SHELL","wget -qO- http://127.0.0.1:9090/-/healthy >/dev/null 2>&1 || curl -fsS http://127.0.0.1:9090/-/healthy >/dev/null 2>&1"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 30s
YAML
      ;;
    *redis*)
      append_block <<YAML
  ${svc}:
    restart: unless-stopped
    mem_limit: 512m
    mem_reservation: 192m
    cpus: "0.75"
    labels:
      autoheal: "true"
    healthcheck:
      test: ["CMD-SHELL","redis-cli ping | grep -q PONG"]
      interval: 20s
      timeout: 5s
      retries: 10
      start_period: 20s
YAML
      ;;
    *postgres*)
      append_block <<YAML
  ${svc}:
    restart: unless-stopped
    mem_limit: 1024m
    mem_reservation: 384m
    cpus: "1.25"
    labels:
      autoheal: "true"
    healthcheck:
      test: ["CMD-SHELL","pg_isready -U \$\${POSTGRES_USER:-postgres} -d \$\${POSTGRES_DB:-postgres} -h 127.0.0.1"]
      interval: 20s
      timeout: 5s
      retries: 10
      start_period: 30s
YAML
      ;;
    *redpanda*|*kafka*)
      append_block <<YAML
  ${svc}:
    restart: unless-stopped
    mem_limit: 2048m
    mem_reservation: 1024m
    cpus: "2.00"
    labels:
      autoheal: "true"
    healthcheck:
      test: ["CMD-SHELL","wget -qO- http://127.0.0.1:9644/v1/status/ready >/dev/null 2>&1 || curl -fsS http://127.0.0.1:9644/v1/status/ready >/dev/null 2>&1"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 45s
YAML
      ;;
    *gateway*|*dex*|*api*|*metrics*|*managerai*|*rosetta*|*usdt*|*qai*)
      append_block <<YAML
  ${svc}:
    restart: unless-stopped
    mem_limit: 768m
    mem_reservation: 256m
    cpus: "1.00"
    labels:
      autoheal: "true"
YAML
      ;;
    *router*|*trade-engine*|*large-exec*|*small-agg*|*risk*|*sim*|*feeder*)
      append_block <<YAML
  ${svc}:
    restart: unless-stopped
    mem_limit: 1024m
    mem_reservation: 384m
    cpus: "1.25"
    labels:
      autoheal: "true"
YAML
      ;;
    *)
      append_block <<YAML
  ${svc}:
    restart: unless-stopped
    mem_limit: 512m
    mem_reservation: 128m
    labels:
      autoheal: "true"
YAML
      ;;
  esac
done

if ! printf '%s\n' "${SERVICES[@]}" | grep -Eq '^autoheal$|autoheal'; then
  append_block <<'YAML'
  autoheal:
    image: willfarrell/autoheal:latest
    restart: unless-stopped
    mem_limit: 128m
    mem_reservation: 64m
    cpus: "0.25"
    read_only: true
    environment:
      AUTOHEAL_CONTAINER_LABEL: all
      AUTOHEAL_INTERVAL: ${AUTOHEAL_INTERVAL:-15}
      AUTOHEAL_START_PERIOD: ${AUTOHEAL_START_PERIOD:-120}
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - ops_isolated
    healthcheck:
      test: ["CMD-SHELL","test -S /var/run/docker.sock"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 10s
    tmpfs:
      - /tmp
YAML
fi

cat >> "${OVERRIDE_FILE}" <<'YAML'

networks:
  ops_isolated:
    driver: bridge
    internal: true
YAML

docker rm -f quantumai-monitoring-grafana quantumai-monitoring-prometheus demo-app-cadvisor-1 2>/dev/null || true

docker compose -f "${BASE_COMPOSE}" -f "${OVERRIDE_FILE}" --env-file "${ENV_FILE}" config > "${BACKUP_DIR}/merged.config.yml"

docker compose -f "${BASE_COMPOSE}" -f "${OVERRIDE_FILE}" --env-file "${ENV_FILE}" up -d --remove-orphans

{
  echo "BASE_COMPOSE=${BASE_COMPOSE}"
  echo "OVERRIDE_FILE=${OVERRIDE_FILE}"
  echo "ENV_FILE=${ENV_FILE}"
  echo "BACKUP_DIR=${BACKUP_DIR}"
  echo
  docker compose -f "${BASE_COMPOSE}" -f "${OVERRIDE_FILE}" --env-file "${ENV_FILE}" ps
  echo
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
  echo
  docker inspect $(docker ps -q) --format '{{.Name}} {{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' 2>/dev/null || true
} | tee "${BACKUP_DIR}/runtime_fix_report.txt"
