#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
COMPOSE_FILE="$REPO/compose.yml"
PROJECT_NAME="quantumai-stack"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$REPO/_backups/compose_fix/$TS"

export DOCKER_CONTEXT="${DOCKER_CONTEXT:-colima-qai}"
export GRAFANA_HOST_PORT="${GRAFANA_HOST_PORT:-13000}"
export PROMETHEUS_HOST_PORT="${PROMETHEUS_HOST_PORT:-19090}"
export CADVISOR_HOST_PORT="${CADVISOR_HOST_PORT:-18080}"

[ -f "$COMPOSE_FILE" ] || { echo "COMPOSE_YOK:$COMPOSE_FILE"; exit 1; }

mkdir -p "$BACKUP_DIR"
cp -f "$COMPOSE_FILE" "$BACKUP_DIR/compose.yml.bak"

ruby <<'RUBY'
require "yaml"
require "date"

compose_file = "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/compose.yml"
raw = File.read(compose_file, encoding: "UTF-8")
data = raw.strip.empty? ? {} : YAML.safe_load(raw, permitted_classes: [Date, Time, Symbol], aliases: true)
data = {} unless data.is_a?(Hash)

def sk(o)
  case o
  when Hash
    o.each_with_object({}) { |(k, v), h| h[k.to_s] = sk(v) }
  when Array
    o.map { |x| sk(x) }
  else
    o
  end
end

data = sk(data)
data["services"] ||= {}
data["networks"] ||= {}
data["volumes"] ||= {}
services = data["services"]

def labels_hash(v)
  case v
  when Hash
    v.each_with_object({}) { |(k, val), h| h[k.to_s] = val.to_s }
  when Array
    v.each_with_object({}) do |item, h|
      next unless item.is_a?(String) && item.include?("=")
      k, val = item.split("=", 2)
      h[k] = val
    end
  else
    {}
  end
end

def env_hash(v)
  case v
  when Hash
    v.each_with_object({}) { |(k, val), h| h[k.to_s] = val }
  when Array
    v.each_with_object({}) do |item, h|
      next unless item.is_a?(String) && item.include?("=")
      k, val = item.split("=", 2)
      h[k] = val
    end
  else
    {}
  end
end

def ports_list(v)
  v.is_a?(Array) ? v : []
end

def ensure_logging!(svc)
  svc["logging"] ||= {
    "driver" => "json-file",
    "options" => {
      "max-size" => "10m",
      "max-file" => "3"
    }
  }
end

def service_ports(svc)
  out = []
  ["ports", "expose"].each do |k|
    next unless svc[k].is_a?(Array)
    svc[k].each do |item|
      case item
      when Integer
        out << item
      when String
        nums = item.scan(/\d+/)
        out << nums.last.to_i unless nums.empty?
      when Hash
        t = item["target"] || item[:target]
        out << t.to_i if t
      end
    end
  end
  out.uniq
end

def fix_depends!(svc)
  dep = svc["depends_on"]
  return unless dep
  if dep.is_a?(Array)
    svc["depends_on"] = dep.map { |x|
      x.to_s
       .gsub("demo-app-cadvisor", "cadvisor")
       .gsub("quantumai-cadvisor", "cadvisor")
       .gsub("demo-app-autoheal", "autoheal")
       .gsub("quantumai-autoheal", "autoheal")
    }
  elsif dep.is_a?(Hash)
    fixed = {}
    dep.each do |k, v|
      nk = k.to_s
            .gsub("demo-app-cadvisor", "cadvisor")
            .gsub("quantumai-cadvisor", "cadvisor")
            .gsub("demo-app-autoheal", "autoheal")
            .gsub("quantumai-autoheal", "autoheal")
      fixed[nk] = v
    end
    svc["depends_on"] = fixed
  end
end

def http_health(port)
  {
    "test" => ["CMD-SHELL", "wget -q -O - http://127.0.0.1:#{port}/health >/dev/null 2>&1 || wget -q -O - http://127.0.0.1:#{port}/ >/dev/null 2>&1 || curl -fsS http://127.0.0.1:#{port}/health >/dev/null 2>&1 || curl -fsS http://127.0.0.1:#{port}/ >/dev/null 2>&1"],
    "interval" => "20s",
    "timeout" => "10s",
    "retries" => 12,
    "start_period" => "30s"
  }
end

def hc_for(name, svc)
  n = name.downcase
  joined = "#{n} #{svc["image"]}".downcase

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
    "test" => ["CMD-SHELL", "rpk cluster health >/dev/null 2>&1 || exit 1"],
    "interval" => "25s",
    "timeout" => "10s",
    "retries" => 15,
    "start_period" => "45s"
  } if joined.include?("redpanda")

  return {
    "test" => ["CMD-SHELL", "wget -q -O - http://127.0.0.1:8080/healthz >/dev/null 2>&1 || curl -fsS http://127.0.0.1:8080/healthz >/dev/null 2>&1"],
    "interval" => "30s",
    "timeout" => "10s",
    "retries" => 10,
    "start_period" => "30s"
  } if joined.include?("cadvisor")

  return {
    "test" => ["CMD-SHELL", "test -S /var/run/docker.sock"],
    "interval" => "30s",
    "timeout" => "5s",
    "retries" => 5,
    "start_period" => "10s"
  } if joined.include?("autoheal")

  ports = service_ports(svc)
  httpish = %w[api gateway dex usdt managerai gli rosetta metrics feeder router risk sim trade large small exec app].any? { |x| n.include?(x) }
  if httpish
    preferred = [80, 3000, 5000, 5001, 5002, 5003, 8000, 8080, 8081, 8088, 9000, 9090]
    port = (ports & preferred).first || ports.first
    return http_health(port) if port
  end

  nil
end

def redpanda_cmd_lowmem(existing)
  current = existing.is_a?(Array) ? existing.map(&:to_s).join(" ") : existing.to_s
  if current.include?("rpk redpanda start")
    base = current
  else
    base = "/usr/bin/rpk redpanda start"
  end
  base = base.gsub(/--smp(?:=|\s+)\S+/, "")
  base = base.gsub(/--memory(?:=|\s+)\S+/, "")
  base = base.gsub(/--reserve-memory(?:=|\s+)\S+/, "")
  base = base.gsub(/\s+/, " ").strip
  "#{base} --smp 1 --memory 1G --reserve-memory 0M"
end

services.each do |name, svc|
  svc = {} unless svc.is_a?(Hash)
  services[name] = svc
  fix_depends!(svc)
  lname = name.downcase
  joined = "#{lname} #{svc["image"]}".downcase

  svc["restart"] = "unless-stopped" unless joined.include?("redpanda")
  ensure_logging!(svc)

  labels = labels_hash(svc["labels"])
  labels["qai.service"] ||= name

  if joined.include?("cadvisor")
    svc["container_name"] = "quantumai-cadvisor"
    svc["restart"] = "unless-stopped"
    svc["image"] = "gcr.io/cadvisor/cadvisor:v0.49.1" if svc["image"].to_s.strip.empty?
    svc["ports"] = ["127.0.0.1:${CADVISOR_HOST_PORT:-18080}:8080"]
    svc["command"] = [
      "--housekeeping_interval=30s",
      "--max_housekeeping_interval=60s",
      "--event_storage_event_limit=default=0",
      "--event_storage_age_limit=default=0",
      "--disable_metrics=percpu,sched,tcp,udp,process",
      "--docker_only=true",
      "--store_container_labels=false"
    ]
    svc["volumes"] = [
      "/var/run/docker.sock:/var/run/docker.sock:ro",
      "/var/run:/var/run:ro",
      "/sys:/sys:ro"
    ]
    svc["mem_limit"] = "256m"
    svc["mem_reservation"] = "128m"
    labels["autoheal"] = "false"
    labels["qai.role"] = "ops-monitor"
    svc["labels"] = labels
    svc["healthcheck"] = hc_for(name, svc)
    next
  end

  if joined.include?("autoheal")
    svc["container_name"] = "quantumai-autoheal"
    svc["restart"] = "unless-stopped"
    svc["image"] = "willfarrell/autoheal:1.2.0" if svc["image"].to_s.strip.empty?
    svc["environment"] = env_hash(svc["environment"]).merge({
      "AUTOHEAL_CONTAINER_LABEL" => "autoheal",
      "AUTOHEAL_INTERVAL" => "15",
      "AUTOHEAL_START_PERIOD" => "60",
      "AUTOHEAL_DEFAULT_STOP_TIMEOUT" => "15"
    })
    svc["volumes"] = ["/var/run/docker.sock:/var/run/docker.sock"]
    svc["mem_limit"] = "128m"
    svc["mem_reservation"] = "64m"
    labels["autoheal"] = "false"
    labels["qai.role"] = "ops-healer"
    svc["labels"] = labels
    svc["healthcheck"] = hc_for(name, svc)
    next
  end

  if joined.include?("redpanda")
    svc["restart"] = "on-failure:5"
    svc["mem_limit"] = "1400m"
    svc["mem_reservation"] = "768m"
    labels["autoheal"] = "false"
    svc["labels"] = labels
    svc["command"] = redpanda_cmd_lowmem(svc["command"])
    svc["healthcheck"] = hc_for(name, svc)
    next
  end

  if joined.include?("postgres")
    svc["mem_limit"] = "1g"
    svc["mem_reservation"] = "512m"
  elsif joined.include?("prometheus") || joined.include?("grafana")
    svc["mem_limit"] = "768m"
    svc["mem_reservation"] = "384m"
  elsif joined.include?("redis")
    svc["mem_limit"] = "512m"
    svc["mem_reservation"] = "256m"
  elsif %w[gateway api dex usdt managerai gli rosetta metrics].any? { |x| joined.include?(x) }
    svc["mem_limit"] = "768m"
    svc["mem_reservation"] = "256m"
  else
    svc["mem_limit"] = svc["mem_limit"] || "512m"
    svc["mem_reservation"] = svc["mem_reservation"] || "192m"
  end

  if joined.include?("grafana")
    svc["ports"] = ["127.0.0.1:${GRAFANA_HOST_PORT:-13000}:3000"]
  elsif joined.include?("prometheus")
    svc["ports"] = ["127.0.0.1:${PROMETHEUS_HOST_PORT:-19090}:9090"]
  end

  labels["autoheal"] = "true" unless labels["autoheal"] == "false"
  svc["labels"] = labels
  svc["healthcheck"] = hc_for(name, svc) if hc_for(name, svc)
end

unless services.key?("cadvisor")
  services["cadvisor"] = {
    "image" => "gcr.io/cadvisor/cadvisor:v0.49.1",
    "container_name" => "quantumai-cadvisor",
    "restart" => "unless-stopped",
    "ports" => ["127.0.0.1:${CADVISOR_HOST_PORT:-18080}:8080"],
    "command" => [
      "--housekeeping_interval=30s",
      "--max_housekeeping_interval=60s",
      "--event_storage_event_limit=default=0",
      "--event_storage_age_limit=default=0",
      "--disable_metrics=percpu,sched,tcp,udp,process",
      "--docker_only=true",
      "--store_container_labels=false"
    ],
    "volumes" => [
      "/var/run/docker.sock:/var/run/docker.sock:ro",
      "/var/run:/var/run:ro",
      "/sys:/sys:ro"
    ],
    "mem_limit" => "256m",
    "mem_reservation" => "128m",
    "labels" => {
      "autoheal" => "false",
      "qai.role" => "ops-monitor",
      "qai.service" => "cadvisor"
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

unless services.key?("autoheal")
  services["autoheal"] = {
    "image" => "willfarrell/autoheal:1.2.0",
    "container_name" => "quantumai-autoheal",
    "restart" => "unless-stopped",
    "environment" => {
      "AUTOHEAL_CONTAINER_LABEL" => "autoheal",
      "AUTOHEAL_INTERVAL" => "15",
      "AUTOHEAL_START_PERIOD" => "60",
      "AUTOHEAL_DEFAULT_STOP_TIMEOUT" => "15"
    },
    "volumes" => ["/var/run/docker.sock:/var/run/docker.sock"],
    "mem_limit" => "128m",
    "mem_reservation" => "64m",
    "labels" => {
      "autoheal" => "false",
      "qai.role" => "ops-healer",
      "qai.service" => "autoheal"
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

File.write(compose_file, YAML.dump(data).sub(/\A---\s*\n/, ""), mode: "w", encoding: "UTF-8")
RUBY

docker context use "${DOCKER_CONTEXT}" >/dev/null 2>&1 || true

docker ps --format '{{.ID}} {{.Names}} {{.Ports}}' | awk '/:3000->|:9090->|:13000->|:19090->|:18080->/ {print $1}' | while read -r cid; do
  [ -n "${cid:-}" ] && docker stop "$cid" >/dev/null 2>&1 || true
done

docker ps -a --format '{{.ID}} {{.Names}}' | awk '/quantumai-stack/ {print $1}' | while read -r cid; do
  [ -n "${cid:-}" ] && docker rm -f "$cid" >/dev/null 2>&1 || true
done

docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" config >/dev/null
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" down --remove-orphans || true
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d --remove-orphans

sleep 20
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps
echo "BACKUP_DIR=$BACKUP_DIR"
echo "GRAFANA=http://127.0.0.1:${GRAFANA_HOST_PORT}"
echo "PROMETHEUS=http://127.0.0.1:${PROMETHEUS_HOST_PORT}"
echo "CADVISOR=http://127.0.0.1:${CADVISOR_HOST_PORT}/healthz"
