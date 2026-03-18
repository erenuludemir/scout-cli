#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:$PATH"
APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"
DOCKER_USERNAME="${DOCKER_USERNAME:-erenuludemir}"
: "${DOCKER_PAT:?[HATA] DOCKER_PAT boş. Örn: export DOCKER_PAT='dckr_pat_xxx'}"
mkdir -p "$APP_DIR/.qai" "$APP_DIR/tools"
date '+%FT%T%z' > "$APP_DIR/.qai/run.timestamp"
if ! command -v brew >/dev/null 2>&1; then /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; eval "$(/opt/homebrew/bin/brew shellenv)" || true; fi
brew update >/dev/null || true
brew install colima jq yq watch tmux >/dev/null || true
FREE_GB="$(df -g /System/Volumes/Data | awk 'NR==2{print $4}')"; if [[ -z "${FREE_GB:-}" || "$FREE_GB" -lt 10 ]]; then echo "[!] Boş alan yetersiz (${FREE_GB:-0} GB). En az 10 GB gerekli."; exit 1; fi
colima stop -f >/dev/null 2>&1 || true
limactl delete -f colima >/dev/null 2>&1 || true
rm -rf "$HOME/.colima" >/dev/null 2>&1 || true
colima start --vm-type vz --vz-rosetta --cpu 4 --memory 6 --disk 25 --dns 1.1.1.1 --dns 8.8.8.8 >/dev/null
docker context use colima >/dev/null
for i in $(seq 1 120); do docker info >/dev/null 2>&1 && break; sleep 1; done
printf "%s" "$DOCKER_PAT" | docker login -u "$DOCKER_USERNAME" --password-stdin >/dev/null
cp -f "$APP_DIR/compose.yml" "$APP_DIR/compose.yml.bak.$(date +%s)" 2>/dev/null || true
cat > "$APP_DIR/compose.yml" <<'YAML'
version: "3.9"
services:
  autoheal:
    image: willfarrell/autoheal:latest
    restart: always
    environment:
      - AUTOHEAL_CONTAINER_LABEL=all
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    healthcheck:
      test: ["CMD","ls","/var/run/docker.sock"]
      interval: 30s
      timeout: 5s
      retries: 3
  watchtower:
    image: containrrr/watchtower:latest
    restart: always
    command: ["--cleanup","--interval","30"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    healthcheck:
      test: ["CMD","watchtower","--version"]
      interval: 30s
      timeout: 5s
      retries: 3
  quantumai-usdt:
    image: quantumai-usdt.apps:latest
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL","python -V >/dev/null 2>&1 || node -v >/dev/null 2>&1"]
      interval: 30s
      timeout: 10s
      retries: 5
  gli-container:
    image: erenuludemir/gli-app:latest
    restart: unless-stopped
    command: ["sh","-lc","pip install -q --no-cache-dir 'werkzeug<3' || true; exec python app.py"]
    healthcheck:
      test: ["CMD-SHELL","python -c 'import socket;print(1)' || exit 1"]
      interval: 20s
      timeout: 5s
      retries: 5
  gli-mainnet:
    image: erenuludemir/gli-app:latest
    restart: unless-stopped
    command: ["sh","-lc","pip install -q --no-cache-dir 'werkzeug<3' || true; exec python app.py"]
    healthcheck:
      test: ["CMD-SHELL","python -c 'import socket;print(1)' || exit 1"]
      interval: 20s
      timeout: 5s
      retries: 5
  gli-sepolia:
    image: erenuludemir/gli-app:latest
    restart: unless-stopped
    command: ["sh","-lc","pip install -q --no-cache-dir 'werkzeug<3' || true; exec python app.py"]
    healthcheck:
      test: ["CMD-SHELL","python -c 'import socket;print(1)' || exit 1"]
      interval: 20s
      timeout: 5s
      retries: 5
YAML
docker compose -f "$APP_DIR/compose.yml" config >/dev/null
docker compose -f "$APP_DIR/compose.yml" pull || true
docker compose -f "$APP_DIR/compose.yml" up -d
if command -v tmux >/dev/null 2>&1; then
  tmux has-session -t ops >/dev/null 2>&1 || tmux new-session -d -s ops
  tmux rename-window -t ops:0 "QAI-Docker"
  tmux send-keys -t ops 'watch -n 5 '\''docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"'\''' C-m
  tmux split-window -h -t ops
  tmux send-keys -t ops 'docker compose -f "$HOME/QuantumAI-Dockerized-System/compose.yml" logs -f' C-m
fi
cp -f "$APP_DIR/Dockerfile" "$APP_DIR/Dockerfile.bak.$(date +%s)" 2>/dev/null || true
cat > "$APP_DIR/Dockerfile" <<'DOCKER'
FROM python:3.10-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY . /app
RUN python -m pip install --upgrade pip && \
    python -m pip install --no-cache-dir "Flask>=2.3.3,<3.0" "Werkzeug>=2.3.7,<3.0" && \
    if [ -f requirements.txt ]; then python -m pip install --no-cache-dir -r requirements.txt || true; fi && \
    if [ -f gli/requirements.txt ]; then python -m pip install --no-cache-dir -r gli/requirements.txt || true; fi && \
    if [ -f gli-app/requirements.txt ]; then python -m pip install --no-cache-dir -r gli-app/requirements.txt || true; fi && \
    true
CMD ["python","app.py"]
DOCKER
append_pin(){ f="$1"; pin="$2"; [ -f "$f" ] || return 0; grep -qiE '^(flask|werkzeug)' "$f" || printf "\n%s\n" "$pin" >> "$f"; }
append_pin "$APP_DIR/requirements.txt" "Flask>=2.3.3,<3.0"
append_pin "$APP_DIR/requirements.txt" "Werkzeug>=2.3.7,<3.0"
append_pin "$APP_DIR/gli/requirements.txt" "Flask>=2.3.3,<3.0"
append_pin "$APP_DIR/gli/requirements.txt" "Werkzeug>=2.3.7,<3.0"
append_pin "$APP_DIR/gli-app/requirements.txt" "Flask>=2.3.3,<3.0"
append_pin "$APP_DIR/gli-app/requirements.txt" "Werkzeug>=2.3.7,<3.0"
docker buildx create --name colima-builder --use >/dev/null 2>&1 || docker buildx use colima-builder >/dev/null 2>&1 || true
docker buildx inspect >/dev/null || true
docker buildx build --platform linux/arm64 -t "${DOCKER_USERNAME}/gli-app:fixed" "$APP_DIR" --push
yq -iy '.services["gli-container"].image="'"${DOCKER_USERNAME}/gli-app:fixed"'"' "$APP_DIR/compose.yml"
yq -iy 'del(.services["gli-container"].command)' "$APP_DIR/compose.yml"
yq -iy '.services["gli-mainnet"].image="'"${DOCKER_USERNAME}/gli-app:fixed"'"' "$APP_DIR/compose.yml"
yq -iy 'del(.services["gli-mainnet"].command)' "$APP_DIR/compose.yml"
yq -iy '.services["gli-sepolia"].image="'"${DOCKER_USERNAME}/gli-app:fixed"'"' "$APP_DIR/compose.yml"
yq -iy 'del(.services["gli-sepolia"].command)' "$APP_DIR/compose.yml"
docker compose -f "$APP_DIR/compose.yml" config >/dev/null
docker compose -f "$APP_DIR/compose.yml" up -d --force-recreate
{
  echo "==== docker ps ===="
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
  echo
  for n in gli-container gli-mainnet gli-sepolia; do
    echo "==== $n ===="
    docker inspect "$n" --format 'Name={{.Name}} Exit={{.State.ExitCode}} OOM={{.State.OOMKilled}} Err={{.State.Error}} Health={{if .State.Health}}{{.State.Health.Status}}{{end}} StartedAt={{.State.StartedAt}} FinishedAt={{.State.FinishedAt}}' || true
    docker logs --tail=80 "$n" 2>&1 | tail -n 40 || true
    echo
  done
} | tee "$APP_DIR/tools/health-check.log" >/dev/null
cat > "$APP_DIR/Seçenek_A_-_Seçenek_B_Terminal_Satırları_Metni.txt" <<'TXT'
docker compose -f "$HOME/QuantumAI-Dockerized-System/compose.yml" up -d
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
docker logs -f gli-container
docker buildx build --platform linux/arm64 -t erenuludemir/gli-app:fixed "$HOME/QuantumAI-Dockerized-System" --push
yq -iy '.services["gli-container"].image="erenuludemir/gli-app:fixed"' "$HOME/QuantumAI-Dockerized-System/compose.yml"; yq -iy 'del(.services["gli-container"].command)' "$HOME/QuantumAI-Dockerized-System/compose.yml"
yq -iy '.services["gli-mainnet"].image="erenuludemir/gli-app:fixed"' "$HOME/QuantumAI-Dockerized-System/compose.yml"; yq -iy 'del(.services["gli-mainnet"].command)' "$HOME/QuantumAI-Dockerized-System/compose.yml"
yq -iy '.services["gli-sepolia"].image="erenuludemir/gli-app:fixed"' "$HOME/QuantumAI-Dockerized-System/compose.yml"; yq -iy 'del(.services["gli-sepolia"].command)' "$HOME/QuantumAI-Dockerized-System/compose.yml"
docker compose -f "$HOME/QuantumAI-Dockerized-System/compose.yml" up -d --force-recreate
TXT
echo "Hazır. Tmux oturumu: ops  | Compose: $APP_DIR/compose.yml  | Sabit image: ${DOCKER_USERNAME}/gli-app:fixed"
