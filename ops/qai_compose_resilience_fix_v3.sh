#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
cd "$REPO"

TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$REPO/_backups/compose_fix/$TS"
mkdir -p "$BACKUP_DIR"

export DOCKER_CONTEXT="${DOCKER_CONTEXT:-colima-qai}"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-quantumai-stack}"
export GRAFANA_HOST_PORT="${GRAFANA_HOST_PORT:-13000}"
export PROMETHEUS_HOST_PORT="${PROMETHEUS_HOST_PORT:-19090}"
export CADVISOR_HOST_PORT="${CADVISOR_HOST_PORT:-18080}"

COMPOSE_CANDIDATES=(
  "$REPO/compose.yml"
  "$REPO/docker-compose.yml"
  "$REPO/compose.master.yml"
  "$REPO/docker-compose.base.yml"
  "$REPO/compose.override.yml"
  "$REPO/docker-compose.override.yml"
)

FOUND_FILES=()
for f in "${COMPOSE_CANDIDATES[@]}"; do
  [ -f "$f" ] && FOUND_FILES+=("$f")
done

if [ "${#FOUND_FILES[@]}" -eq 0 ]; then
  echo "COMPOSE_DOSYASI_BULUNAMADI:$REPO"
  exit 1
fi

for f in "${FOUND_FILES[@]}"; do
  cp -f "$f" "$BACKUP_DIR/$(basename "$f").bak"
done

RUBYLIB="" ruby <<'RUBY'
require "yaml"
require "date"

repo = "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
files = %w[
  compose.yml
  docker-compose.yml
  compose.master.yml
  docker-compose.base.yml
  compose.override.yml
  docker-compose.override.yml
].map { |f| File.join(repo, f) }.select { |p| File.file?(p) }

def stringify_keys(obj)
  case obj
  when Hash
    obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify_keys(v) }
  when Array
    obj.map { |x| stringify_keys(x) }
  else
    obj
  end
end

def load_yaml(path)
  raw = File.read(path, encoding: "UTF-8")
  data = raw.strip.empty? ? {} : YAML.safe_load(raw, permitted_classes: [Date, Time, Symbol], aliases: true)
  data = {} unless data.is_a?(Hash)
  data = stringify_keys(data)
  data["services"] = {} unless data["services"].is_a?(Hash)
  data["networks"] = {} unless data["networks"].is_a?(Hash)
  data
end

def save_yaml(path, data)
  rendered = YAML.dump(data)
  rendered = rendered.sub(/\A---\s*\n/, "")
  File.write(path, rendered, mode: "w", encoding: "UTF-8")
end

def normalize_labels(v)
  return {} if v.nil?
  if v.is_a?(Array)
    out = {}
    v.each do |item|
      next unless item.is_a?(String) && item.include?("=")
      k, val = item.split("=", 2)
      out[k] = val
    end
    return out
  end
  return v if v.is_a?(Hash)
  {}
end

def normalize_environment(v)
  return {} if v.nil?
  if v.is_a?(Array)
    out = {}
    v.each do |item|
      next unless item.is_a?(String) && item.include?("=")
      k, val = item.split("=", 2)
      out[k] = val
    end
    return out
  end
  return v if v.is_a?(Hash)
  {}
end

def ensure_logging(svc)
  svc["logging"] ||= {
    "driver" => "json-file",
    "options" => {
      "max-size" => "10m",
      "max-file" => "3"
    }
  }
end

def detect_mem(name, svc)
  joined = "#{name} #{svc["image"]}".downcase
  return ["2g", "1g"] if joined.include?("redpanda") || joined.match?(/\bkafka\b/)
  return ["1g", "512m"] if joined.include?("postgres")
  return ["768m", "384m"] if joined.include?("prometheus") || joined.include?("grafana")
  return ["512m", "256m"] if joined.include?("redis")
  return ["256m", "128m"] if joined.include?("cadvisor")
  return ["128m", "64m"] if joined.include?("autoheal")
  return ["768m", "256m"] if %w[gateway api dex usdt managerai gli rosetta metrics].any? { |x| joined.include?(x) }
  ["512m", "192m"]
end

def ports_from_service(svc)
  ports = []
  %w[ports expose].each do |key|
    next unless svc[key].is_a?(Array)
    svc[key].each do |item|
      case item
      when Integer
        ports << item
      when String
        nums = item.scan(/\d+/)
        ports << nums.last.to_i unless nums.empty?
      when Hash
        t = item["target"] || item[:target]
        ports << t.to_i if t
      end
    end
  end
  ports.uniq
end

def healthcheck_for(name, svc)
  joined = "#{name} #{svc["image"]}".downcase

  return {
    "test" => ["CMD-SHELL", "test -S /var/run/docker.sock"],
    "interval" => "30s",
    "timeout" => "5s",
    "retries" => 5,
    "start_period" => "10s"
  } if joined.include?("autoheal")

  return {
    "test" => ["CMD-SHELL", "wget -q -O - http://127.0.0.1:8080/healthz >/dev/null 2>&1 || curl -fsS http://127.0.0.1:8080/healthz >/dev/null 2>&1"],
    "interval" => "30s",
    "timeout" => "10s",
    "retries" => 10,
    "start_period" => "30s"
  } if joined.include?("cadvisor")

  return {
    "test" => ["CMD", "redis-cli", "ping"],
    "interval" => "15s",
    "timeout" => "5s",
    "retries" => 20,
    "start_period" => "15s"
  } if joined.include?("redis")

  return {
    "test" => ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER:-postgres} -d $${POSTGRES_DB:-postgres} || exit 1"],
    "interval" => "15s",
    "timeout" => "5s",
    "retries" => 20,
    "start_period" => "20s"
  } if joined.include?("postgres")

  return {
    "test" => ["CMD-SHELL", "wget -q -O - http://127.0.0.1:9090/-/ready >/dev/null 2>&1 || curl -fsS http://127.0.0.1:9090/-/ready >/dev/null 2>&1"],
    "interval" => "20s",
    "timeout" => "10s",
    "retries" => 15,
    "start_period" => "30s"
  } if joined.include?("prometheus")

  return {
    "test" => ["CMD-SHELL", "wget -q -O - http://127.0.0.1:3000/api/health >/dev/null 2>&1 || curl -fsS http://127.0.0.1:3000/api/health >/dev/null 2>&1"],
    "interval" => "20s",
    "timeout" => "10s",
    "retries" => 15,
    "start_period" => "40s"
  } if joined.include?("grafana")

  return {
    "test" => ["CMD-SHELL", "rpk cluster health >/dev/null 2>&1 || rpk cluster info >/dev/null 2>&1 || exit 1"],
    "interval" => "20s",
    "timeout" => "10s",
    "retries" => 20,
    "start_period" => "60s"
  } if joined.include?("redpanda")

  ports = ports_from_service(svc)
  httpish = %w[api gateway dex usdt managerai gli rosetta metrics].any? { |x| name.downcase.include?(x) }
  if httpish
    preferred = [80, 3000, 5000, 5001, 5002, 5003, 8000, 8080, 8081, 8088, 9000, 9090]
    port = (ports & preferred).first || ports.first
    if port
      return {
        "test" => ["CMD-SHELL", "wget -q -O - http://127.0.0.1:#{port}/health >/dev/null 2>&1 || wget -q -O - http://127.0.0.1:#{port}/ >/dev/null 2>&1 || curl -fsS http://127.0.0.1:#{port}/health >/dev/null 2>&1 || curl -fsS http://127.0.0.1:#{port}/ >/dev/null 2>&1"],
        "interval" => "20s",
        "timeout" => "10s",
        "retries" => 15,
        "start_period" => "30s"
      }
    end
  end

  nil
end

def patch_ports(name, svc)
  lname = name.downcase
  if lname.include?("grafana")
    svc["ports"] = ["127.0.0.1:${GRAFANA_HOST_PORT:-13000}:3000"]
  elsif lname.include?("prometheus")
    svc["ports"] = ["127.0.0.1:${PROMETHEUS_HOST_PORT:-19090}:9090"]
  elsif lname.include?("cadvisor")
    svc["ports"] = ["127.0.0.1:${CADVISOR_HOST_PORT:-18080}:8080"]
  end
  svc
end

def preferred_networks(existing_networks)
  out = []
  out << "monitoring" if existing_networks.key?("monitoring")
  out << "default"
  out.uniq
end

def patch_cadvisor(existing_networks)
  {
    "image" => "gcr.io/cadvisor/cadvisor:v0.49.1",
    "container_name" => "quantumai-cadvisor",
    "restart" => "unless-stopped",
    "ports" => ["127.0.0.1:${CADVISOR_HOST_PORT:-18080}:8080"],
    "command" => [
      "--housekeeping_interval=30s",
      "--max_housekeeping_interval=60s",
      "--event_storage_event_limit=default=0",
      "--event_storage_age_limit=default=0",
      "--disable_metrics=advtcp,cpu_topology,disk,diskIO,memory_numa,network,percpu,process,referenced_memory,resctrl,sched,tcp,udp",
      "--docker_only=true",
      "--store_container_labels=false"
    ],
    "volumes" => [
      "/var/run/docker.sock:/var/run/docker.sock:ro",
      "/var/run:/var/run:ro",
      "/sys:/sys:ro"
    ],
    "networks" => preferred_networks(existing_networks),
    "mem_limit" => "256m",
    "mem_reservation" => "128m",
    "labels" => {
      "autoheal" => "false",
      "qai.role" => "ops-monitor"
    },
    "healthcheck" => {
      "test" => ["CMD-SHELL", "wget -q -O - http://127.0.0.1:8080/healthz >/dev/null 2>&1 || curl -fsS http://127.0.0.1:8080/healthz >/dev/null 2>&1"],
      "interval" => "30s",
      "timeout" => "10s",
      "retries" => 10,
      "start_period" => "30s"
    },
    "logging" => {
      "driver" => "json-file",
      "options" => {
        "max-size" => "10m",
        "max-file" => "3"
      }
    }
  }
end

def patch_autoheal(existing_networks)
  {
    "image" => "willfarrell/autoheal:1.2.0",
    "container_name" => "quantumai-autoheal",
    "restart" => "unless-stopped",
    "environment" => {
      "AUTOHEAL_CONTAINER_LABEL" => "autoheal",
      "AUTOHEAL_INTERVAL" => "15",
      "AUTOHEAL_START_PERIOD" => "60",
      "AUTOHEAL_DEFAULT_STOP_TIMEOUT" => "15"
    },
    "volumes" => [
      "/var/run/docker.sock:/var/run/docker.sock"
    ],
    "networks" => preferred_networks(existing_networks),
    "mem_limit" => "128m",
    "mem_reservation" => "64m",
    "labels" => {
      "autoheal" => "false",
      "qai.role" => "ops-healer"
    },
    "healthcheck" => {
      "test" => ["CMD-SHELL", "test -S /var/run/docker.sock"],
      "interval" => "30s",
      "timeout" => "5s",
      "retries" => 5,
      "start_period" => "10s"
    },
    "logging" => {
      "driver" => "json-file",
      "options" => {
        "max-size" => "10m",
        "max-file" => "3"
      }
    }
  }
end

def patch_service(name, svc, existing_networks)
  svc = {} unless svc.is_a?(Hash)
  svc = stringify_keys(svc)
  lname = name.downcase

  return patch_cadvisor(existing_networks) if lname.include?("cadvisor")
  return patch_autoheal(existing_networks) if lname.include?("autoheal")

  svc["restart"] = "unless-stopped"

  mem_limit, mem_res = detect_mem(name, svc)
  svc["mem_limit"] = mem_limit
  svc["mem_reservation"] = mem_res

  labels = normalize_labels(svc["labels"])
  labels["autoheal"] = "true"
  labels["qai.service"] ||= name
  svc["labels"] = labels

  env = normalize_environment(svc["environment"])
  svc["environment"] = env unless env.empty?

  hc = healthcheck_for(name, svc)
  svc["healthcheck"] = hc if hc

  ensure_logging(svc)
  patch_ports(name, svc)

  svc
end

files.each do |path|
  data = load_yaml(path)
  data["networks"]["default"] ||= {}
  services = data["services"]

  services.keys.each do |name|
    services[name] = patch_service(name, services[name], data["networks"])
  end

  unless services.keys.any? { |n| n.downcase.include?("autoheal") }
    services["autoheal"] = patch_autoheal(data["networks"])
  end

  unless services.keys.any? { |n| n.downcase.include?("cadvisor") }
    services["cadvisor"] = patch_cadvisor(data["networks"])
  end

  data["services"] = services
  save_yaml(path, data)
end
RUBY

docker context use "${DOCKER_CONTEXT}" >/dev/null 2>&1 || true

docker ps --format '{{.ID}} {{.Names}} {{.Ports}}' | awk '/:3000->|:9090->|:18080->|:13000->|:19090->/ {print $1" "$2}' | while read -r cid cname; do
  case "$cname" in
    quantumai-monitoring-*|demo-app-*|*grafana*|*prometheus*|*cadvisor*)
      docker stop "$cid" >/dev/null 2>&1 || true
      ;;
  esac
done

docker ps -a --format '{{.ID}} {{.Names}}' | awk '/demo-app|quantumai-monitoring|quantumai-cadvisor|quantumai-autoheal/ {print $1}' | while read -r cid; do
  docker rm -f "$cid" >/dev/null 2>&1 || true
done

docker network ls --format '{{.Name}}' | awk '/^demo-app_|^quantumai-monitoring$/ {print $1}' | while read -r net; do
  docker network rm "$net" >/dev/null 2>&1 || true
done

PRIMARY_COMPOSE=""
for c in "$REPO/compose.yml" "$REPO/docker-compose.yml"; do
  [ -f "$c" ] && PRIMARY_COMPOSE="$c" && break
done

if [ -z "$PRIMARY_COMPOSE" ]; then
  echo "PRIMARY_COMPOSE_BULUNAMADI"
  exit 1
fi

docker compose -f "$PRIMARY_COMPOSE" -p "${COMPOSE_PROJECT_NAME}" config >/dev/null
docker compose -f "$PRIMARY_COMPOSE" -p "${COMPOSE_PROJECT_NAME}" down --remove-orphans || true
docker compose -f "$PRIMARY_COMPOSE" -p "${COMPOSE_PROJECT_NAME}" up -d --remove-orphans

sleep 20
docker compose -f "$PRIMARY_COMPOSE" -p "${COMPOSE_PROJECT_NAME}" ps
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo "GRAFANA=http://127.0.0.1:${GRAFANA_HOST_PORT}"
echo "PROMETHEUS=http://127.0.0.1:${PROMETHEUS_HOST_PORT}"
echo "CADVISOR=http://127.0.0.1:${CADVISOR_HOST_PORT}/healthz"
echo "BACKUP_DIR=$BACKUP_DIR"
