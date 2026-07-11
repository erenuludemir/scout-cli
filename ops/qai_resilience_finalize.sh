#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
cd "$REPO"

TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$REPO/_backups/resilience_finalize/$TS"
mkdir -p "$BACKUP_DIR"

export DOCKER_CONTEXT="${DOCKER_CONTEXT:-colima-qai}"
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

ruby <<'RUBY'
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

def s(obj)
  case obj
  when Hash
    obj.each_with_object({}) { |(k, v), h| h[k.to_s] = s(v) }
  when Array
    obj.map { |x| s(x) }
  else
    obj
  end
end

def load_yaml(path)
  raw = File.read(path, encoding: "UTF-8")
  data = raw.strip.empty? ? {} : YAML.safe_load(raw, permitted_classes: [Date, Time, Symbol], aliases: true)
  data = {} unless data.is_a?(Hash)
  data = s(data)
  data["services"] = {} unless data["services"].is_a?(Hash)
  data["networks"] = {} unless data["networks"].is_a?(Hash)
  data["networks"]["default"] ||= {}
  data
end

def dump_yaml(path, data)
  txt = YAML.dump(data)
  txt = txt.sub(/\A---\s*\n/, "")
  File.write(path, txt, mode: "w", encoding: "UTF-8")
end

def normalize_labels(labels)
  labels = {} if labels.nil?
  if labels.is_a?(Array)
    out = {}
    labels.each do |x|
      next unless x.is_a?(String) && x.include?("=")
      k, v = x.split("=", 2)
      out[k] = v
    end
    labels = out
  end
  labels = {} unless labels.is_a?(Hash)
  s(labels)
end

def normalize_env(env)
  env = {} if env.nil?
  if env.is_a?(Array)
    out = {}
    env.each do |x|
      next unless x.is_a?(String) && x.include?("=")
      k, v = x.split("=", 2)
      out[k] = v
    end
    env = out
  end
  env = {} unless env.is_a?(Hash)
  s(env)
end

def set_cmd_value(cmd, from, to)
  case cmd
  when Array
    cmd.map { |x| x.is_a?(String) ? x.gsub(from, to) : x }
  when String
    cmd.gsub(from, to)
  else
    cmd
  end
end

def add_or_replace_flag(cmd, flag_prefix, new_token)
  case cmd
  when Array
    found = false
    out = cmd.map do |x|
      if x.is_a?(String) && x.start_with?(flag_prefix)
        found = true
        new_token
      else
        x
      end
    end
    out << new_token unless found
    out
  when String
    if cmd.match?(Regexp.new(Regexp.escape(flag_prefix) + '\S*'))
      cmd.gsub(Regexp.new(Regexp.escape(flag_prefix) + '\S*'), new_token)
    else
      "#{cmd} #{new_token}"
    end
  else
    cmd
  end
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

def stateful?(joined)
  joined.include?("redpanda") || joined.include?("postgres") || joined.include?("redis")
end

def detect_mem(name, svc)
  joined = "#{name} #{svc["image"]}".downcase
  return ["1536m", "768m"] if joined.include?("redpanda") || joined.match?(/\bkafka\b/)
  return ["1g", "512m"] if joined.include?("postgres")
  return ["768m", "384m"] if joined.include?("prometheus") || joined.include?("grafana")
  return ["512m", "256m"] if joined.include?("redis")
  return ["256m", "128m"] if joined.include?("cadvisor")
  return ["128m", "64m"] if joined.include?("autoheal")
  return ["768m", "256m"] if %w[gateway api dex usdt managerai gli rosetta metrics].any? { |x| joined.include?(x) }
  ["512m", "192m"]
end

def ports_from_service(svc)
  out = []
  %w[ports expose].each do |k|
    v = svc[k]
    next unless v.is_a?(Array)
    v.each do |x|
      case x
      when Integer
        out << x
      when String
        nums = x.scan(/\d+/)
        out << nums.last.to_i unless nums.empty?
      when Hash
        t = x["target"] || x[:target]
        out << t.to_i if t
      end
    end
  end
  out.uniq
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
    "start_period" => "20s"
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
    "test" => ["CMD-SHELL", "rpk cluster info >/dev/null 2>&1 || rpk cluster health >/dev/null 2>&1 || exit 1"],
    "interval" => "30s",
    "timeout" => "15s",
    "retries" => 10,
    "start_period" => "45s"
  } if joined.include?("redpanda")

  ports = ports_from_service(svc)
  httpish = %w[api gateway dex usdt managerai gli rosetta metrics].any? { |x| name.downcase.include?(x) }
  if httpish
    preferred = [80, 3000, 5000, 5001, 5002, 5003, 8000, 8012, 8080, 8081, 8088, 9000, 9090]
    port = (ports & preferred).first || ports.first
    if port
      return {
        "test" => ["CMD-SHELL", "wget -q -O - http://127.0.0.1:#{port}/health >/dev/null 2>&1 || wget -q -O - http://127.0.0.1:#{port}/healthz >/dev/null 2>&1 || wget -q -O - http://127.0.0.1:#{port}/ >/dev/null 2>&1 || curl -fsS http://127.0.0.1:#{port}/health >/dev/null 2>&1 || curl -fsS http://127.0.0.1:#{port}/healthz >/dev/null 2>&1 || curl -fsS http://127.0.0.1:#{port}/ >/dev/null 2>&1"],
        "interval" => "20s",
        "timeout" => "10s",
        "retries" => 15,
        "start_period" => "30s"
      }
    end
  end

  nil
end

def patch_special_ports(name, svc)
  lname = name.downcase
  svc["ports"] = ["127.0.0.1:${GRAFANA_HOST_PORT:-13000}:3000"] if lname.include?("grafana")
  svc["ports"] = ["127.0.0.1:${PROMETHEUS_HOST_PORT:-19090}:9090"] if lname.include?("prometheus")
  svc["ports"] = ["127.0.0.1:${CADVISOR_HOST_PORT:-18080}:8080"] if lname.include?("cadvisor")
  svc
end

def preferred_networks(networks)
  out = []
  out << "monitoring" if networks.key?("monitoring")
  out << "default"
  out.uniq
end

def cadvisor_service(networks)
  {
    "image" => "gcr.io/cadvisor/cadvisor:v0.49.1",
    "container_name" => "quantumai-cadvisor",
    "profiles" => ["ops"],
    "restart" => "unless-stopped",
    "ports" => ["127.0.0.1:${CADVISOR_HOST_PORT:-18080}:8080"],
    "command" => [
      "--docker_only=true",
      "--store_container_labels=false",
      "--disable_metrics=percpu,sched,tcp,udp,process",
      "--housekeeping_interval=30s",
      "--max_housekeeping_interval=60s",
      "--event_storage_event_limit=default=0",
      "--event_storage_age_limit=default=0"
    ],
    "volumes" => [
      "/var/run/docker.sock:/var/run/docker.sock:ro",
      "/sys:/sys:ro"
    ],
    "networks" => preferred_networks(networks),
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
      "start_period" => "20s"
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

def autoheal_service(networks)
  {
    "image" => "willfarrell/autoheal:1.2.0",
    "container_name" => "quantumai-autoheal",
    "profiles" => ["ops"],
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
    "networks" => preferred_networks(networks),
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

def patch_service(name, svc, networks)
  svc = {} unless svc.is_a?(Hash)
  svc = s(svc)
  joined = "#{name} #{svc["image"]}".downcase
  lname = name.downcase

  return cadvisor_service(networks) if joined.include?("cadvisor")
  return autoheal_service(networks) if joined.include?("autoheal")

  svc["restart"] = stateful?(joined) ? "on-failure:5" : "unless-stopped"

  mem_limit, mem_reservation = detect_mem(name, svc)
  svc["mem_limit"] = mem_limit
  svc["mem_reservation"] = mem_reservation

  labels = normalize_labels(svc["labels"])
  labels["autoheal"] = stateful?(joined) ? "false" : "true"
  labels["qai.service"] ||= name
  svc["labels"] = labels

  env = normalize_env(svc["environment"])
  svc["environment"] = env unless env.empty?

  if joined.include?("redpanda")
    svc["command"] = set_cmd_value(svc["command"], "--memory=2G", "--memory=1536M")
    svc["command"] = set_cmd_value(svc["command"], "--memory=2048M", "--memory=1536M")
    svc["command"] = set_cmd_value(svc["command"], "--smp=2", "--smp=1")
    svc["command"] = add_or_replace_flag(svc["command"], "--memory=", "--memory=1536M")
    svc["command"] = add_or_replace_flag(svc["command"], "--smp=", "--smp=1")
    svc["environment"]["REDPANDA_MEMORY"] ||= "1536M" unless svc["environment"].nil?
    svc["environment"]["REDPANDA_SMP"] ||= "1" unless svc["environment"].nil?
  end

  svc["healthcheck"] = healthcheck_for(name, svc) if healthcheck_for(name, svc)
  ensure_logging(svc)
  patch_special_ports(name, svc)
  svc
end

files.each do |path|
  data = load_yaml(path)
  services = data["services"]

  services.keys.each do |name|
    services[name] = patch_service(name, services[name], data["networks"])
  end

  unless services.keys.any? { |n| n.downcase.include?("cadvisor") }
    services["cadvisor"] = cadvisor_service(data["networks"])
  end

  unless services.keys.any? { |n| n.downcase.include?("autoheal") }
    services["autoheal"] = autoheal_service(data["networks"])
  end

  data["services"] = services
  dump_yaml(path, data)
end
RUBY

cat > "$REPO/compose.resilience.override.yml" <<'YAML'
services:
  cadvisor:
    profiles: ["ops"]
  autoheal:
    profiles: ["ops"]
YAML

docker context use "${DOCKER_CONTEXT}" >/dev/null 2>&1 || true

docker ps --format '{{.ID}} {{.Names}} {{.Ports}}' | awk '/:3000->|:9090->|:18080->|:13000->|:19090->/ {print $1}' | while read -r cid; do
  [ -n "${cid:-}" ] && docker stop "$cid" >/dev/null 2>&1 || true
done

docker ps -a --format '{{.ID}} {{.Names}}' | awk '/quantumai-monitoring|demo-app|quantumai-cadvisor|quantumai-autoheal/ {print $1}' | while read -r cid; do
  [ -n "${cid:-}" ] && docker rm -f "$cid" >/dev/null 2>&1 || true
done

PRIMARY_COMPOSE=""
for c in "$REPO/compose.yml" "$REPO/docker-compose.yml"; do
  [ -f "$c" ] && PRIMARY_COMPOSE="$c" && break
done

if [ -z "$PRIMARY_COMPOSE" ]; then
  echo "PRIMARY_COMPOSE_BULUNAMADI"
  exit 1
fi

docker compose -f "$PRIMARY_COMPOSE" -f "$REPO/compose.resilience.override.yml" -p quantumai-stack config >/dev/null
docker compose -f "$PRIMARY_COMPOSE" -f "$REPO/compose.resilience.override.yml" -p quantumai-stack down --remove-orphans || true
docker compose -f "$PRIMARY_COMPOSE" -f "$REPO/compose.resilience.override.yml" -p quantumai-stack up -d --remove-orphans
COMPOSE_PROFILES=ops docker compose -f "$PRIMARY_COMPOSE" -f "$REPO/compose.resilience.override.yml" -p quantumai-stack up -d cadvisor autoheal

sleep 20

docker compose -f "$PRIMARY_COMPOSE" -f "$REPO/compose.resilience.override.yml" -p quantumai-stack ps
echo "----- HEALTHCHECK -----"
curl -fsS "http://127.0.0.1:${GRAFANA_HOST_PORT}/api/health" >/dev/null 2>&1 && echo "GRAFANA_OK=http://127.0.0.1:${GRAFANA_HOST_PORT}" || echo "GRAFANA_FAIL=http://127.0.0.1:${GRAFANA_HOST_PORT}"
curl -fsS "http://127.0.0.1:${PROMETHEUS_HOST_PORT}/-/ready" >/dev/null 2>&1 && echo "PROMETHEUS_OK=http://127.0.0.1:${PROMETHEUS_HOST_PORT}" || echo "PROMETHEUS_FAIL=http://127.0.0.1:${PROMETHEUS_HOST_PORT}"
curl -fsS "http://127.0.0.1:${CADVISOR_HOST_PORT}/healthz" >/dev/null 2>&1 && echo "CADVISOR_OK=http://127.0.0.1:${CADVISOR_HOST_PORT}/healthz" || echo "CADVISOR_FAIL=http://127.0.0.1:${CADVISOR_HOST_PORT}/healthz"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo "BACKUP_DIR=$BACKUP_DIR"
