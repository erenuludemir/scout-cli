#!/bin/zsh
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
cd "$REPO"

TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$REPO/_backups/compose_fix/$TS"
mkdir -p "$BACKUP_DIR"

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

python3 - <<'PY'
import os, re, sys, subprocess, json
from pathlib import Path

repo = Path("/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3")
files = [
    repo / "compose.yml",
    repo / "docker-compose.yml",
    repo / "compose.master.yml",
    repo / "docker-compose.base.yml",
    repo / "compose.override.yml",
    repo / "docker-compose.override.yml",
]
files = [p for p in files if p.exists()]

def ensure_pyyaml():
    try:
        import yaml  # noqa
        return
    except Exception:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "--user", "pyyaml"])
ensure_pyyaml()
import yaml

def load_yaml(path):
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    if not isinstance(data, dict):
        data = {}
    if "services" not in data or not isinstance(data["services"], dict):
        data["services"] = {}
    return data

def save_yaml(path, data):
    with open(path, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, sort_keys=False, allow_unicode=True, width=4096)

def normalize_labels(svc):
    labels = svc.get("labels", {})
    if labels is None:
        labels = {}
    if isinstance(labels, list):
        out = {}
        for item in labels:
            if isinstance(item, str) and "=" in item:
                k, v = item.split("=", 1)
                out[k] = v
        labels = out
    if not isinstance(labels, dict):
        labels = {}
    return labels

def detect_mem(name, svc):
    lname = name.lower()
    image = str(svc.get("image", "")).lower()
    joined = f"{lname} {image}"
    if "redpanda" in joined or re.search(r"\bkafka\b", joined):
        return "2g", "1g"
    if "postgres" in joined:
        return "1g", "512m"
    if "prometheus" in joined or "grafana" in joined:
        return "768m", "384m"
    if "redis" in joined:
        return "512m", "256m"
    if "cadvisor" in joined:
        return "256m", "128m"
    if "autoheal" in joined:
        return "128m", "64m"
    if any(x in joined for x in ["gateway", "api", "dex", "usdt", "managerai", "gli", "rosetta", "metrics"]):
        return "768m", "256m"
    return "512m", "192m"

def healthcheck_for(name, svc):
    lname = name.lower()
    image = str(svc.get("image", "")).lower()
    joined = f"{lname} {image}"

    if "autoheal" in joined:
        return {
            "test": ["CMD-SHELL", "test -S /var/run/docker.sock"],
            "interval": "30s",
            "timeout": "5s",
            "retries": 5,
            "start_period": "10s",
        }
    if "cadvisor" in joined:
        return {
            "test": ["CMD-SHELL", "wget -q -O - http://127.0.0.1:8080/healthz >/dev/null 2>&1 || curl -fsS http://127.0.0.1:8080/healthz >/dev/null 2>&1"],
            "interval": "30s",
            "timeout": "10s",
            "retries": 10,
            "start_period": "30s",
        }
    if "redis" in joined:
        return {
            "test": ["CMD", "redis-cli", "ping"],
            "interval": "15s",
            "timeout": "5s",
            "retries": 20,
            "start_period": "15s",
        }
    if "postgres" in joined:
        return {
            "test": ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-postgres} -d ${POSTGRES_DB:-postgres} || exit 1"],
            "interval": "15s",
            "timeout": "5s",
            "retries": 20,
            "start_period": "20s",
        }
    if "prometheus" in joined:
        return {
            "test": ["CMD-SHELL", "wget -q -O - http://127.0.0.1:9090/-/ready >/dev/null 2>&1 || curl -fsS http://127.0.0.1:9090/-/ready >/dev/null 2>&1"],
            "interval": "20s",
            "timeout": "10s",
            "retries": 15,
            "start_period": "30s",
        }
    if "grafana" in joined:
        return {
            "test": ["CMD-SHELL", "wget -q -O - http://127.0.0.1:3000/api/health >/dev/null 2>&1 || curl -fsS http://127.0.0.1:3000/api/health >/dev/null 2>&1"],
            "interval": "20s",
            "timeout": "10s",
            "retries": 15,
            "start_period": "40s",
        }
    if "redpanda" in joined:
        return {
            "test": ["CMD-SHELL", "rpk cluster health >/dev/null 2>&1 || exit 1"],
            "interval": "20s",
            "timeout": "10s",
            "retries": 20,
            "start_period": "40s",
        }

    ports = []
    for key in ("ports", "expose"):
        vals = svc.get(key, [])
        if isinstance(vals, list):
            for item in vals:
                if isinstance(item, int):
                    ports.append(int(item))
                elif isinstance(item, str):
                    m = re.findall(r"(\d+)", item)
                    if m:
                        ports.append(int(m[-1]))
                elif isinstance(item, dict):
                    target = item.get("target")
                    if isinstance(target, int):
                        ports.append(target)

    httpish = any(x in lname for x in ["api", "gateway", "dex", "usdt", "managerai", "gli", "rosetta", "metrics"])
    if httpish:
        port = None
        for p in ports:
            if p in {80, 3000, 5000, 5001, 5002, 5003, 8000, 8080, 8081, 8088, 9000, 9090}:
                port = p
                break
        if port is None and ports:
            port = ports[0]
        if port is not None:
            return {
                "test": ["CMD-SHELL", f"wget -q -O - http://127.0.0.1:{port}/health >/dev/null 2>&1 || wget -q -O - http://127.0.0.1:{port}/ >/dev/null 2>&1 || curl -fsS http://127.0.0.1:{port}/health >/dev/null 2>&1 || curl -fsS http://127.0.0.1:{port}/ >/dev/null 2>&1"],
                "interval": "20s",
                "timeout": "10s",
                "retries": 15,
                "start_period": "30s",
            }

    return None

def patch_ports(name, svc):
    lname = name.lower()
    if "grafana" in lname:
        svc["ports"] = ["127.0.0.1:${GRAFANA_HOST_PORT:-13000}:3000"]
    elif "prometheus" in lname:
        svc["ports"] = ["127.0.0.1:${PROMETHEUS_HOST_PORT:-19090}:9090"]
    return svc

def patch_cadvisor(name, svc):
    lname = name.lower()
    if "cadvisor" not in lname:
        return svc
    svc.clear()
    svc.update({
        "image": "gcr.io/cadvisor/cadvisor:v0.49.1",
        "container_name": "quantumai-cadvisor",
        "restart": "unless-stopped",
        "privileged": False,
        "ports": ["127.0.0.1:${CADVISOR_HOST_PORT:-18080}:8080"],
        "command": [
            "--housekeeping_interval=30s",
            "--max_housekeeping_interval=60s",
            "--event_storage_event_limit=default=0",
            "--event_storage_age_limit=default=0",
            "--disable_root_cgroup_stats=true",
            "--docker_only=true",
        ],
        "volumes": [
            "/:/rootfs:ro",
            "/var/run:/var/run:ro",
            "/var/run/docker.sock:/var/run/docker.sock:ro",
            "/sys:/sys:ro",
        ],
        "networks": ["default"],
        "mem_limit": "256m",
        "mem_reservation": "128m",
        "labels": {
            "autoheal": "false",
            "qai.role": "ops-monitor",
        },
        "healthcheck": {
            "test": ["CMD-SHELL", "wget -q -O - http://127.0.0.1:8080/healthz >/dev/null 2>&1 || curl -fsS http://127.0.0.1:8080/healthz >/dev/null 2>&1"],
            "interval": "30s",
            "timeout": "10s",
            "retries": 10,
            "start_period": "30s",
        },
        "logging": {
            "driver": "json-file",
            "options": {"max-size": "10m", "max-file": "3"},
        },
    })
    return svc

def patch_autoheal(name, svc):
    lname = name.lower()
    if "autoheal" not in lname:
        return svc
    svc.clear()
    svc.update({
        "image": "willfarrell/autoheal:1.2.0",
        "container_name": "quantumai-autoheal",
        "restart": "unless-stopped",
        "environment": {
            "AUTOHEAL_CONTAINER_LABEL": "autoheal",
            "AUTOHEAL_INTERVAL": "15",
            "AUTOHEAL_START_PERIOD": "60",
            "AUTOHEAL_DEFAULT_STOP_TIMEOUT": "15",
        },
        "volumes": ["/var/run/docker.sock:/var/run/docker.sock"],
        "networks": ["default"],
        "mem_limit": "128m",
        "mem_reservation": "64m",
        "labels": {
            "autoheal": "false",
            "qai.role": "ops-healer",
        },
        "healthcheck": {
            "test": ["CMD-SHELL", "test -S /var/run/docker.sock"],
            "interval": "30s",
            "timeout": "5s",
            "retries": 5,
            "start_period": "10s",
        },
        "logging": {
            "driver": "json-file",
            "options": {"max-size": "10m", "max-file": "3"},
        },
    })
    return svc

def patch_service(name, svc):
    if not isinstance(svc, dict):
        svc = {}

    lname = name.lower()

    svc = patch_cadvisor(name, svc)
    svc = patch_autoheal(name, svc)

    if "cadvisor" not in lname and "autoheal" not in lname:
        svc["restart"] = "unless-stopped"
        mem_limit, mem_res = detect_mem(name, svc)
        svc["mem_limit"] = mem_limit
        svc["mem_reservation"] = mem_res
        labels = normalize_labels(svc)
        labels["autoheal"] = "true"
        labels.setdefault("qai.service", name)
        svc["labels"] = labels
        if "logging" not in svc:
            svc["logging"] = {
                "driver": "json-file",
                "options": {"max-size": "10m", "max-file": "3"},
            }
        hc = healthcheck_for(name, svc)
        if hc:
            svc["healthcheck"] = hc
        svc = patch_ports(name, svc)
    return svc

for path in files:
    data = load_yaml(path)
    if "networks" not in data or not isinstance(data["networks"], dict):
        data["networks"] = {}
    data["networks"].setdefault("default", {})
    services = data.get("services", {})
    for name in list(services.keys()):
        services[name] = patch_service(name, services[name])

    base_names = set(services.keys())
    if not any("autoheal" in n.lower() for n in base_names):
        services["autoheal"] = patch_autoheal("autoheal", {})
    if not any("cadvisor" in n.lower() for n in base_names):
        services["cadvisor"] = patch_cadvisor("cadvisor", {})

    data["services"] = services
    save_yaml(path, data)
PY

if command -v docker >/dev/null 2>&1; then
  docker context use colima-qai >/dev/null 2>&1 || true
fi

docker ps --format '{{.ID}} {{.Names}} {{.Ports}}' | awk '/:3000->|:9090->/ {print $1" "$2}' | while read -r cid cname; do
  case "$cname" in
    quantumai-monitoring-*|demo-app-*|*grafana*|*prometheus*)
      docker stop "$cid" >/dev/null 2>&1 || true
      ;;
  esac
done

docker ps -a --format '{{.ID}} {{.Names}}' | awk '/demo-app|quantumai-monitoring/ {print $1}' | while read -r cid; do
  docker rm -f "$cid" >/dev/null 2>&1 || true
done

docker network ls --format '{{.Name}}' | awk '/^demo-app_|^quantumai-monitoring/ {print $1}' | while read -r net; do
  docker network rm "$net" >/dev/null 2>&1 || true
done

export DOCKER_CONTEXT="${DOCKER_CONTEXT:-colima-qai}"
export GRAFANA_HOST_PORT="${GRAFANA_HOST_PORT:-13000}"
export PROMETHEUS_HOST_PORT="${PROMETHEUS_HOST_PORT:-19090}"
export CADVISOR_HOST_PORT="${CADVISOR_HOST_PORT:-18080}"

PRIMARY_COMPOSE=""
for c in "$REPO/compose.yml" "$REPO/docker-compose.yml"; do
  [ -f "$c" ] && PRIMARY_COMPOSE="$c" && break
done

if [ -z "$PRIMARY_COMPOSE" ]; then
  echo "PRIMARY_COMPOSE_BULUNAMADI"
  exit 1
fi

docker compose -f "$PRIMARY_COMPOSE" -p quantumai-stack config >/dev/null
docker compose -f "$PRIMARY_COMPOSE" -p quantumai-stack down --remove-orphans || true
docker compose -f "$PRIMARY_COMPOSE" -p quantumai-stack up -d --remove-orphans

sleep 15
docker compose -f "$PRIMARY_COMPOSE" -p quantumai-stack ps
echo "GRAFANA=http://127.0.0.1:${GRAFANA_HOST_PORT}"
echo "PROMETHEUS=http://127.0.0.1:${PROMETHEUS_HOST_PORT}"
echo "CADVISOR=http://127.0.0.1:${CADVISOR_HOST_PORT}/healthz"
echo "BACKUP_DIR=$BACKUP_DIR"
