#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
COMPOSE_FILE="$REPO/compose.yml"
PROJECT_NAME="quantumai-stack"
TS="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$REPO/_backups/compose_fix/$TS"

export DOCKER_CONTEXT="${DOCKER_CONTEXT:-colima-qai}"
export GRAFANA_HOST_PORT="${GRAFANA_HOST_PORT:-13000}"
export PROMETHEUS_HOST_PORT="${PROMETHEUS_HOST_PORT:-19190}"
export CADVISOR_HOST_PORT="${CADVISOR_HOST_PORT:-18080}"

[ -f "$COMPOSE_FILE" ] || { echo "COMPOSE_YOK:$COMPOSE_FILE"; exit 1; }

mkdir -p "$BACKUP_DIR"
cp -f "$COMPOSE_FILE" "$BACKUP_DIR/compose.yml.bak"

python3 - "$COMPOSE_FILE" <<'PY'
import sys, re
from pathlib import Path

compose_file = Path(sys.argv[1])
text = compose_file.read_text(encoding="utf-8")

def ensure_service_block(src: str, service_name: str, block: str) -> str:
    pattern = re.compile(rf'(?ms)^  {re.escape(service_name)}:\n(?:^(?:    |\t).*\n|^\n)*')
    if pattern.search(src):
        return pattern.sub(block, src, count=1)
    if not re.search(r'(?m)^services:\s*$', src):
        src = "services:\n" + src
    return re.sub(r'(?m)^services:\s*$', lambda m: m.group(0) + "\n" + block.rstrip("\n") + "\n", src, count=1)

def replace_in_service_block(src: str, service_name: str, transform):
    pattern = re.compile(rf'(?ms)^  {re.escape(service_name)}:\n(?:^(?:    |\t).*\n|^\n)*')
    m = pattern.search(src)
    if not m:
        return src
    old = m.group(0)
    new = transform(old)
    return src[:m.start()] + new + src[m.end():]

def normalize_depends(block: str) -> str:
    block = block.replace("demo-app-cadvisor", "cadvisor")
    block = block.replace("quantumai-cadvisor", "cadvisor")
    block = block.replace("demo-app-autoheal", "autoheal")
    block = block.replace("quantumai-autoheal", "autoheal")
    return block

def set_or_replace_scalar(block: str, key: str, value: str) -> str:
    patt = re.compile(rf'(?m)^    {re.escape(key)}:.*\n')
    line = f"    {key}: {value}\n"
    if patt.search(block):
        return patt.sub(line, block, count=1)
    lines = block.splitlines(True)
    insert_at = 1 if len(lines) >= 1 else 0
    lines.insert(insert_at, line)
    return ''.join(lines)

def set_or_replace_ports(block: str, lines_new: str) -> str:
    patt = re.compile(r'(?ms)^    ports:\n(?:^      .*\n)+')
    if patt.search(block):
        return patt.sub(lines_new, block, count=1)
    lines = block.splitlines(True)
    insert_at = len(lines)
    for idx, line in enumerate(lines):
        if re.match(r'(?m)^    (environment|depends_on|networks|volumes|healthcheck|logging|labels):', line):
            insert_at = idx
            break
    lines.insert(insert_at, lines_new)
    return ''.join(lines)

def replace_command_any(block: str, cmd_line: str) -> str:
    patt1 = re.compile(r'(?ms)^    command:.*?(?=^    [A-Za-z0-9_]+\s*:|^  [A-Za-z0-9_-]+:\n|\Z)')
    if patt1.search(block):
        return patt1.sub(cmd_line, block, count=1)
    lines = block.splitlines(True)
    lines.insert(1, cmd_line)
    return ''.join(lines)

def ensure_logging(block: str) -> str:
    logging_block = (
        "    logging:\n"
        "      driver: json-file\n"
        "      options:\n"
        "        max-size: \"10m\"\n"
        "        max-file: \"3\"\n"
    )
    patt = re.compile(r'(?ms)^    logging:\n(?:^      .*\n|^        .*\n)+')
    if patt.search(block):
        return patt.sub(logging_block, block, count=1)
    return block.rstrip("\n") + "\n" + logging_block

def parse_labels_block(block: str):
    m = re.search(r'(?ms)^    labels:\n((?:^      .*\n)+)', block)
    labels = {}
    if not m:
        return labels, None
    for line in m.group(1).splitlines():
        s = line.strip()
        if not s or ":" not in s:
            continue
        k, v = s.split(":", 1)
        labels[k.strip()] = v.strip().strip('"').strip("'")
    return labels, m

def ensure_labels(block: str, service_name: str, autoheal_value: str | None) -> str:
    labels, m = parse_labels_block(block)
    labels["qai.service"] = service_name
    if autoheal_value is not None:
        labels["autoheal"] = autoheal_value
    out = "    labels:\n" + "".join(f"      {k}: \"{v}\"\n" for k, v in labels.items())
    if m:
        start, end = m.start(), m.end()
        return block[:start] + out + block[end:]
    return block.rstrip("\n") + "\n" + out

def ensure_healthcheck(block: str, health_block: str) -> str:
    patt = re.compile(r'(?ms)^    healthcheck:\n(?:^      .*\n|^        .*\n|^          .*\n)+')
    if patt.search(block):
        return patt.sub(health_block, block, count=1)
    return block.rstrip("\n") + "\n" + health_block

def generic_http_health(port: int) -> str:
    return (
        "    healthcheck:\n"
        "      test:\n"
        f"        - CMD-SHELL\n"
        f"        - wget -q -O - http://127.0.0.1:{port}/health >/dev/null 2>&1 || wget -q -O - http://127.0.0.1:{port}/ >/dev/null 2>&1 || curl -fsS http://127.0.0.1:{port}/health >/dev/null 2>&1 || curl -fsS http://127.0.0.1:{port}/ >/dev/null 2>&1\n"
        "      interval: 20s\n"
        "      timeout: 10s\n"
        "      retries: 12\n"
        "      start_period: 30s\n"
    )

def infer_port(block: str):
    ports = re.findall(r'(?m)^\s*-\s*"?[^"\n]*:(\d+)"?\s*$', block)
    if ports:
        return int(ports[0])
    expose = re.findall(r'(?m)^\s*-\s*"?(\d+)"?\s*$', block)
    if expose:
        return int(expose[0])
    return None

cadvisor_block = """  cadvisor:
    image: gcr.io/cadvisor/cadvisor:v0.49.1
    container_name: quantumai-cadvisor
    restart: unless-stopped
    ports:
      - "127.0.0.1:${CADVISOR_HOST_PORT:-18080}:8080"
    command:
      - --housekeeping_interval=30s
      - --max_housekeeping_interval=60s
      - --event_storage_event_limit=default=0
      - --event_storage_age_limit=default=0
      - --disable_metrics=percpu,sched,tcp,udp,process
      - --docker_only=true
      - --store_container_labels=false
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
    mem_limit: 256m
    mem_reservation: 128m
    labels:
      autoheal: "false"
      qai.role: "ops-monitor"
      qai.service: "cadvisor"
    healthcheck:
      test:
        - CMD-SHELL
        - wget -q -O - http://127.0.0.1:8080/healthz >/dev/null 2>&1 || curl -fsS http://127.0.0.1:8080/healthz >/dev/null 2>&1
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 30s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
"""

autoheal_block = """  autoheal:
    image: willfarrell/autoheal:1.2.0
    container_name: quantumai-autoheal
    restart: unless-stopped
    environment:
      AUTOHEAL_CONTAINER_LABEL: "autoheal"
      AUTOHEAL_INTERVAL: "15"
      AUTOHEAL_START_PERIOD: "60"
      AUTOHEAL_DEFAULT_STOP_TIMEOUT: "15"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    mem_limit: 128m
    mem_reservation: 64m
    labels:
      autoheal: "false"
      qai.role: "ops-healer"
      qai.service: "autoheal"
    healthcheck:
      test:
        - CMD-SHELL
        - test -S /var/run/docker.sock
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 10s
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
"""

text = normalize_depends(text)
text = ensure_service_block(text, "cadvisor", cadvisor_block)
text = ensure_service_block(text, "autoheal", autoheal_block)

service_names = re.findall(r'(?m)^  ([A-Za-z0-9_.-]+):\s*$', text)
service_names = [s for s in service_names if s not in ("services", "networks", "volumes")]

for svc in service_names:
    def transform(block, svc=svc):
        block = normalize_depends(block)
        lname = svc.lower()
        joined = block.lower()

        if svc == "cadvisor":
            return cadvisor_block
        if svc == "autoheal":
            return autoheal_block

        if "redpanda" in lname:
            block = set_or_replace_scalar(block, "restart", "on-failure:5")
            block = set_or_replace_scalar(block, "mem_limit", "900m")
            block = set_or_replace_scalar(block, "mem_reservation", "512m")
            block = replace_command_any(
                block,
                '    command: "/usr/bin/rpk redpanda start --overprovisioned --smp 1 --memory 768M --reserve-memory 0M --check=false --advertise-kafka-addr=PLAINTEXT://redpanda:9092 --kafka-addr=PLAINTEXT://0.0.0.0:9092 --pandaproxy-addr=0.0.0.0:8082 --rpc-addr=0.0.0.0:33145"\n'
            )
            block = ensure_labels(block, svc, "false")
            block = ensure_logging(block)
            block = ensure_healthcheck(
                block,
                "    healthcheck:\n"
                "      test:\n"
                "        - CMD-SHELL\n"
                "        - rpk cluster health >/dev/null 2>&1 || exit 1\n"
                "      interval: 25s\n"
                "      timeout: 10s\n"
                "      retries: 15\n"
                "      start_period: 45s\n"
            )
            return block

        block = set_or_replace_scalar(block, "restart", "unless-stopped")
        if "postgres" in joined:
            block = set_or_replace_scalar(block, "mem_limit", "1g")
            block = set_or_replace_scalar(block, "mem_reservation", "512m")
            block = ensure_healthcheck(
                block,
                "    healthcheck:\n"
                "      test:\n"
                "        - CMD-SHELL\n"
                "        - pg_isready -U $${POSTGRES_USER:-postgres} -d $${POSTGRES_DB:-postgres} || exit 1\n"
                "      interval: 15s\n"
                "      timeout: 5s\n"
                "      retries: 20\n"
                "      start_period: 20s\n"
            )
            block = ensure_labels(block, svc, "true")
        elif "redis" in joined:
            block = set_or_replace_scalar(block, "mem_limit", "512m")
            block = set_or_replace_scalar(block, "mem_reservation", "256m")
            block = ensure_healthcheck(
                block,
                "    healthcheck:\n"
                "      test:\n"
                "        - CMD\n"
                "        - redis-cli\n"
                "        - ping\n"
                "      interval: 15s\n"
                "      timeout: 5s\n"
                "      retries: 20\n"
                "      start_period: 15s\n"
            )
            block = ensure_labels(block, svc, "true")
        elif "prometheus" in joined:
            block = set_or_replace_scalar(block, "mem_limit", "768m")
            block = set_or_replace_scalar(block, "mem_reservation", "384m")
            block = set_or_replace_ports(block, '    ports:\n      - "127.0.0.1:${PROMETHEUS_HOST_PORT:-19190}:9090"\n')
            block = ensure_healthcheck(
                block,
                "    healthcheck:\n"
                "      test:\n"
                "        - CMD-SHELL\n"
                "        - wget -q -O - http://127.0.0.1:9090/-/ready >/dev/null 2>&1 || curl -fsS http://127.0.0.1:9090/-/ready >/dev/null 2>&1\n"
                "      interval: 20s\n"
                "      timeout: 10s\n"
                "      retries: 15\n"
                "      start_period: 30s\n"
            )
            block = ensure_labels(block, svc, "true")
        elif "grafana" in joined:
            block = set_or_replace_scalar(block, "mem_limit", "768m")
            block = set_or_replace_scalar(block, "mem_reservation", "384m")
            block = set_or_replace_ports(block, '    ports:\n      - "127.0.0.1:${GRAFANA_HOST_PORT:-13000}:3000"\n')
            block = ensure_healthcheck(
                block,
                "    healthcheck:\n"
                "      test:\n"
                "        - CMD-SHELL\n"
                "        - wget -q -O - http://127.0.0.1:3000/api/health >/dev/null 2>&1 || curl -fsS http://127.0.0.1:3000/api/health >/dev/null 2>&1\n"
                "      interval: 20s\n"
                "      timeout: 10s\n"
                "      retries: 15\n"
                "      start_period: 40s\n"
            )
            block = ensure_labels(block, svc, "true")
        elif any(x in lname for x in ["gateway", "api", "dex", "usdt", "managerai", "gli", "rosetta", "metrics", "feeder", "router", "risk", "sim", "trade", "large", "small", "exec", "app"]):
            block = set_or_replace_scalar(block, "mem_limit", "768m")
            block = set_or_replace_scalar(block, "mem_reservation", "256m")
            port = infer_port(block)
            if port:
                block = ensure_healthcheck(block, generic_http_health(port))
            block = ensure_labels(block, svc, "true")
        else:
            block = set_or_replace_scalar(block, "mem_limit", "512m")
            block = set_or_replace_scalar(block, "mem_reservation", "192m")
            block = ensure_labels(block, svc, "true")

        block = ensure_logging(block)
        return block

    text = replace_in_service_block(text, svc, transform)

compose_file.write_text(text, encoding="utf-8")
PY

docker context use "${DOCKER_CONTEXT}" >/dev/null 2>&1 || true

for p in "${PROMETHEUS_HOST_PORT}" "${GRAFANA_HOST_PORT}" "${CADVISOR_HOST_PORT}" 9090 3000 8080; do
  docker ps --format '{{.ID}} {{.Ports}}' | awk -v port="$p" '$0 ~ (":" port "->") {print $1}' | while read -r cid; do
    [ -n "${cid:-}" ] && docker stop "$cid" >/dev/null 2>&1 || true
  done
done

docker ps -a --format '{{.ID}} {{.Names}}' | awk '/quantumai-stack|quantumai-cadvisor|quantumai-autoheal/ {print $1}' | while read -r cid; do
  [ -n "${cid:-}" ] && docker rm -f "$cid" >/dev/null 2>&1 || true
done

docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" config >/dev/null

docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d --remove-orphans --no-deps \
  cadvisor autoheal prometheus grafana redis quantumai-stack-mcai-redis-1 2>/dev/null || true

docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" up -d --remove-orphans || true

sleep 8

docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" stop quantumai-stack-demo-app-redpanda-1 2>/dev/null || true
docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" rm -f -s quantumai-stack-demo-app-redpanda-1 2>/dev/null || true

docker ps --format '{{.Names}}' | grep -E '^quantumai-stack-demo-app-redpanda-1$' >/dev/null 2>&1 && docker rm -f quantumai-stack-demo-app-redpanda-1 >/dev/null 2>&1 || true

docker compose -f "$COMPOSE_FILE" -p "$PROJECT_NAME" ps || true
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' || true

echo "BACKUP_DIR=$BACKUP_DIR"
echo "PROMETHEUS=http://127.0.0.1:${PROMETHEUS_HOST_PORT}"
echo "GRAFANA=http://127.0.0.1:${GRAFANA_HOST_PORT}"
echo "CADVISOR=http://127.0.0.1:${CADVISOR_HOST_PORT}/healthz"
