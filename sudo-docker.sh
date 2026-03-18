#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-erenuludemir/gli-app:latest}"
CONTAINER="${CONTAINER:-gli-app}"
HOST_PORT="${HOST_PORT:-8080}"
PROFILE="${PROFILE:-default}"
CPU="${CPU:-4}"
MEMORY="${MEMORY:-6}"
DISK="${DISK:-100}"
HEALTH_PATH="${HEALTH_PATH:-/health}"
ENV_FILE="${ENV_FILE:-.env}"
SCOUT="${SCOUT:-1}"
NUKE_COLIMA="${NUKE_COLIMA:-1}"
SESSION="${SESSION:-ops}"
BREW_TMP="$HOME/.qai_tmpbrew"
COLIMA_CORE_VERSION="${COLIMA_CORE_VERSION:-v0.8.3}"
CORE_DISK_IMAGE="${CORE_DISK_IMAGE:-$HOME/Downloads/ubuntu-24.04-minimal-cloudimg-arm64-docker.qcow2}"
RECOVERED_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Kurtarilanlar"
RECOVER_BACKUP="$HOME/Downloads/Recovered_Backup_$(date +%Y%m%d_%H%M%S)"

say(){ printf "\033[1;36m[%s]\033[0m %s\n" "$1" "${2:-}"; }

say "0" "Başlangıç disk özeti"; df -h /

say "1" "iCloud Kurtarilanlar büyük dosyaları taşınıyor (silinmiyor)"
mkdir -p "$RECOVER_BACKUP" || true
for f in \
  "$RECOVERED_DIR/diffdisk" \
  "$RECOVERED_DIR/Docker.raw" \
  "$RECOVERED_DIR/trained_model.json"
do
  [ -e "$f" ] && mv -n "$f" "$RECOVER_BACKUP/" || true
done

say "1" "Homebrew TEMP ve genel temizlik"
export HOMEBREW_TEMP="$BREW_TMP" HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_INSTALL_CLEANUP=1
mkdir -p "$BREW_TMP" || true
rm -rf "$HOME/.Trash/"* "$HOME/Library/Logs/DiagnosticReports/"* \
       "$HOME/Library/Caches/"* "$HOME/Library/Developer/Xcode/DerivedData/"* \
       "$HOME/.zsh_sessions/"*.history* 2>/dev/null || true
command -v brew >/dev/null 2>&1 && brew cleanup -s || true

say "1" "Docker prune (kullanılmayan nesneler ve gerekirse volume'lar)"
if command -v docker >/dev/null 2>&1; then
  docker system prune -af || true
  docker system prune -af --volumes || true
fi

command -v colima >/dev/null 2>&1 || { echo "colima yok (brew install colima docker docker-compose)"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "docker CLI yok"; exit 1; }
command -v tmux   >/dev/null 2>&1 || { echo "tmux yok (brew install tmux)"; exit 1; }

tmux new-session -d -s "$SESSION" || true
tmux new -As "$SESSION" -d || true

say "4" "Colima stop + prune"
colima stop --profile "$PROFILE" || true
colima prune --force --profile "$PROFILE" || true
rm -rf "$HOME/.colima/$PROFILE/docker/var/lib/docker/buildkit" || true

say "5" "Colima core imajı indiriliyor: $COLIMA_CORE_VERSION"
mkdir -p "$(dirname "$CORE_DISK_IMAGE")"
if [ ! -f "$CORE_DISK_IMAGE" ]; then
  curl -fL --retry 5 --retry-delay 2 \
    "https://github.com/abiosoft/colima-core/releases/download/${COLIMA_CORE_VERSION}/$(basename "$CORE_DISK_IMAGE")" \
    -o "$CORE_DISK_IMAGE"
fi

say "6" "Colima start (disk-image ile) --cpu $CPU --memory $MEMORY --disk $DISK"
if ! colima start --profile "$PROFILE" --cpu "$CPU" --memory "$MEMORY" --disk "$DISK" -i "$CORE_DISK_IMAGE"; then
  if [ "$NUKE_COLIMA" = "1" ]; then
    say "6" "Başarısız → tam sıfırlama (delete -f) ve tekrar deneme"
    colima delete --force --profile "$PROFILE" || true
    colima start  --profile "$PROFILE" --cpu "$CPU" --memory "$MEMORY" --disk "$DISK" -i "$CORE_DISK_IMAGE"
  else
    echo "Colima start başarısız"; exit 1
  fi
fi

say "7" "Docker context 'colima' etkinleştiriliyor"
docker context use colima >/dev/null 2>&1 || {
  docker context rm -f colima || true
  docker context create colima --docker "host=unix://$HOME/.colima/$PROFILE/docker.sock" || true
  docker context use colima
}

say "8" "Docker credsStore=osxkeychain ayarlanıyor"
mkdir -p "$HOME/.docker"
python3 - <<'PY'
import json, pathlib
p=pathlib.Path.home()/".docker"/"config.json"
cfg={}
if p.exists():
  try: cfg=json.loads(p.read_text())
  except: cfg={}
cfg["credsStore"]="osxkeychain"
cfg.setdefault("currentContext", cfg.get("currentContext","colima"))
p.write_text(json.dumps(cfg,indent=2))
print("~/.docker/config.json yazıldı")
PY
command -v docker-credential-osxkeychain >/dev/null 2>&1 || brew install docker-credential-helper || true

say "9" "/etc/docker/daemon.json yazılıyor (VM içinde)"
colima ssh --profile "$PROFILE" -- sudo mkdir -p /etc/docker
colima ssh --profile "$PROFILE" -- bash -lc 'cat >/tmp/daemon.json<<JSON
{
  "debug": true,
  "experimental": true,
  "live-restore": true,
  "features": { "buildkit": true },
  "max-concurrent-downloads": 10,
  "default-address-pools": [
    {"base":"10.50.0.0/16","size":24},
    {"base":"10.51.0.0/16","size":24}
  ]
}
JSON
sudo mv /tmp/daemon.json /etc/docker/daemon.json'

say "10" "Colima restart"
colima stop --profile "$PROFILE" || true
colima start --profile "$PROFILE" --cpu "$CPU" --memory "$MEMORY" --disk "$DISK" -i "$CORE_DISK_IMAGE"

say "11" "docker info bekleniyor"
for i in $(seq 1 40); do
  docker info >/dev/null 2>&1 && break
  sleep 1
  if [ "$i" -eq 40 ]; then echo "Docker daemon ulaşılamıyor"; exit 1; fi
done

if [ -n "${DOCKER_PAT:-}" ]; then
  echo "$DOCKER_PAT" | docker login --username "erenuludemir" --password-stdin || true
fi

say "13" "Image pull & run: $IMAGE  →  http://localhost:${HOST_PORT}${HEALTH_PATH}"
docker pull "$IMAGE" || true
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
RUN_ENV_FLAG=""
[ -f "$ENV_FILE" ] && RUN_ENV_FLAG="--env-file $ENV_FILE"
docker run -d --restart unless-stopped --name "$CONTAINER" $RUN_ENV_FLAG -p "${HOST_PORT}:5000" "$IMAGE" >/dev/null

for i in $(seq 1 30); do
  if curl -fsS "http://localhost:${HOST_PORT}${HEALTH_PATH}" >/dev/null; then
    echo "Health: OK"
    break
  fi
  sleep 1
  if [ "$i" -eq 30 ]; then
    echo "Health: FAIL → docker logs:"
    docker logs "$CONTAINER" || true
    exit 1
  fi
done

if [ "$SCOUT" = "1" ] && docker scout version >/dev/null 2>&1; then
  docker scout quickview "$IMAGE" || true
  docker scout cves --only-severities critical,high "$IMAGE" || true
fi

say "16" "Disk özeti (son)"; df -h /
echo
say "OK" "READY: http://localhost:${HOST_PORT}/  |  Health: http://localhost:${HOST_PORT}${HEALTH_PATH}"
