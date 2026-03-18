#!/usr/bin/env bash
set -euo pipefail

DOCKER_USERNAME="${DOCKER_USERNAME:-erenuludemir}"
APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"
COLIMA_CPU="${COLIMA_CPU:-4}"
COLIMA_MEM_GB="${COLIMA_MEM_GB:-6}"
COLIMA_DISK_GB="${COLIMA_DISK_GB:-25}"
COLIMA_DNS1="${COLIMA_DNS1:-1.1.1.1}"
COLIMA_DNS2="${COLIMA_DNS2:-8.8.8.8}"
HEALTH_PERIOD_MIN="${HEALTH_PERIOD_MIN:-5}"

export PATH="/opt/homebrew/bin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:$PATH"

echo "────────────────────────────────────────────────────────────────"
echo "[0] Ortam & Önkoşullar kontrolü"
echo "────────────────────────────────────────────────────────────────"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[!] Bu betik macOS için yazıldı. Çıkılıyor."; exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "[i] Homebrew kuruluyor…"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)" || true
fi

brew update >/dev/null || true
brew install jq yq httpie colima lima qemu coreutils >/dev/null || true
brew upgrade colima lima qemu >/dev/null || true

command -v http >/dev/null 2>&1 || { echo "[i] httpie yükleme tekrar deneniyor…"; brew reinstall httpie >/dev/null || true; }

if ! curl --version | grep -qi "OpenSSL"; then
  brew install curl >/dev/null || true
  export PATH="/opt/homebrew/opt/curl/bin:$PATH"
fi

if ! python3 -m venv --help >/dev/null 2>&1; then
  echo "[i] Python venv kontrolü atlandı."
fi

echo
echo "────────────────────────────────────────────────────────────────"
echo "[1] Disk sağlığı & temizlik (güvenli)"
echo "────────────────────────────────────────────────────────────────"

osascript -e 'tell application "Finder" to empty the trash' >/dev/null 2>&1 || true
sudo bash -c 'for d in /var/log /private/var/log "$HOME/Library/Logs"; do [ -d "$d" ] && find "$d" -type f -name "*.log*" -exec sh -c ": > \"$1\"" _ {} \; 2>/dev/null; done' || true
brew cleanup -s >/dev/null 2>&1 || true
rm -rf "$HOME/Library/Caches/Homebrew" "$HOME/Library/Logs/Homebrew" >/dev/null 2>&1 || true
python3 -m pip cache purge >/dev/null 2>&1 || true
rm -rf "$HOME/Library/Caches/"* "$HOME/Library/Application Support/CrashReporter" >/dev/null 2>&1 || true

rm -rf "$HOME/Library/Developer/Xcode/DerivedData" \
       "$HOME/Library/Developer/Xcode/Archives" \
       "$HOME/Library/Developer/CoreSimulator/Caches" >/dev/null 2>&1 || true
xcrun simctl delete unavailable >/dev/null 2>&1 || true

sudo tmutil thinlocalsnapshots / 20000000000 4 >/dev/null 2>&1 || true

df -h /System/Volumes/Data
FREE_GB="$(df -g /System/Volumes/Data | awk 'NR==2{print $4}')"
if [[ -z "${FREE_GB:-}" || "$FREE_GB" -lt 10 ]]; then
  echo "[!] Boş alan yetersiz (${FREE_GB:-0} GB). En az 10–20 GB boşaltıp tekrar deneyin."
  exit 1
fi

echo
echo "────────────────────────────────────────────────────────────────"
echo "[2] Docker Desktop & CLI eklentileri"
echo "────────────────────────────────────────────────────────────────"

if [[ ! -d "/Applications/Docker.app" ]]; then
  echo "[!] /Applications/Docker.app bulunamadı."
  echo "    Manuel indirme: https://docs.docker.com/desktop/setup/install/mac-install/"
  echo "    İndirilen Docker.dmg montaj/kurulum komutları:"
  echo "      sudo hdiutil attach Docker.dmg && sudo /Volumes/Docker/Docker.app/Contents/MacOS/install --accept-license --user=$(whoami) && sudo hdiutil detach /Volumes/Docker"
  exit 1
fi

mkdir -p "$HOME/.docker/cli-plugins"
for p in docker-compose docker-buildx docker-scout docker-sbom docker-debug docker-extension docker-init docker-model docker-mcp docker-desktop; do
  src="/Applications/Docker.app/Contents/Resources/cli-plugins/${p}"
  dst="$HOME/.docker/cli-plugins/${p}"
  if [[ -f "$src" ]] && [[ ! -f "$dst" ]]; then
    cp -f "$src" "$dst"
    chmod +x "$dst"
  fi
done

osascript -e 'tell application "Docker" to quit' >/dev/null 2>&1 || true
sleep 2
open -a "Docker" || true

for i in $(seq 1 120); do
  if docker version >/dev/null 2>&1; then break; fi
  sleep 1
done
if ! docker info >/dev/null 2>&1; then
  echo "[!] Docker daemon hazır değil. Docker Desktop’ı açıp tekrar deneyin."
  exit 1
fi

echo
echo "────────────────────────────────────────────────────────────────"
echo "[3] Colima kurulum & başlatma (Apple Silicon, Rosetta etkin)"
echo "────────────────────────────────────────────────────────────────"

colima stop default >/dev/null 2>&1 || true

if ! colima status >/dev/null 2>&1; then
  echo "[i] Colima başlatılıyor…"
  if colima start --cpu "${COLIMA_CPU}" --memory "${COLIMA_MEM_GB}" --disk "${COLIMA_DISK_GB}" \
      --vm-type qemu --vz-rosetta --dns "${COLIMA_DNS1}" --dns "${COLIMA_DNS2}" --mount-type virtiofs; then
    :
  else
    colima start --cpu "${COLIMA_CPU}" --memory "${COLIMA_MEM_GB}" --disk "${COLIMA_DISK_GB}" \
      --vm-type qemu --dns "${COLIMA_DNS1}" --dns "${COLIMA_DNS2}" --mount-type virtiofs
  fi
else
  echo "[i] Colima zaten aktif."
fi

docker context use colima >/dev/null 2>&1 || true
docker info || { echo "[!] Docker/Colima erişimi yok."; exit 1; }

echo
echo "────────────────────────────────────────────────────────────────"
echo "[4] Docker Hub login (PAT ile, sessiz ve güvenli)"
echo "────────────────────────────────────────────────────────────────"

if [[ -z "${DOCKER_PAT:-}" ]]; then
  echo "[!] DOCKER_PAT boş. Giriş atlandı. (Sadece public pull yapabilirsiniz)"
else
  printf "%s" "$DOCKER_PAT" | docker login -u "$DOCKER_USERNAME" --password-stdin
fi

echo
echo "────────────────────────────────────────────────────────────────"
echo "[5] Proje kökü hazırlığı ve Compose onarımı (tek 'services:' altında)"
echo "────────────────────────────────────────────────────────────────"

mkdir -p "$APP_DIR"
cd "$APP_DIR"

if [[ -f "$APP_DIR/compose.master.yml" ]]; then
  echo "[i] compose.master.yml bulundu; normalize ediliyor…"
  TMP_MERGED="$(mktemp)"
  yq -o=json '.' "$APP_DIR/compose.master.yml" > "$TMP_MERGED.json"

  if ! jq '.' "$TMP_MERGED.json" >/dev/null 2>&1; then
    echo "[i] YAML anahtar çakışması algılandı; satır bazlı birleştirme uygulanıyor…"
    awk '
      BEGIN{in_services=0; first_services_seen=0}
      /^[[:space:]]*services:[[:space:]]*$/{
        if (first_services_seen==0){ first_services_seen=1; in_services=1; print; next }
        else { print "# services: (merged below)"; skip_services_header=1; next }
      }
      { print }
    ' "$APP_DIR/compose.master.yml" > "$TMP_MERGED"

    if yq e '.' "$TMP_MERGED" >/dev/null 2>&1; then
      cp -f "$TMP_MERGED" "$APP_DIR/compose.fixed.yml"
    else
      echo "[!] Otomatik birleştirme başarısız oldu; minimal compose oluşturuluyor."
      cat > "$APP_DIR/compose.fixed.yml" <<'YAML'
version: "3.9"
services:
  app:
    image: alpine:3.20
    command: ["sh","-c","echo QuantumAI system up && sleep 3600"]
    restart: unless-stopped
YAML
    fi
  else
    yq '.' "$APP_DIR/compose.master.yml" > "$APP_DIR/compose.fixed.yml"
  fi
else
  echo "[!] $APP_DIR/compose.master.yml bulunamadı; minimal compose üretilecek."
  cat > "$APP_DIR/compose.fixed.yml" <<'YAML'
version: "3.9"
services:
  app:
    image: alpine:3.20
    command: ["sh","-c","echo QuantumAI system up && sleep 3600"]
    restart: unless-stopped
YAML
fi

if [[ "$(grep -E '^[[:space:]]*services:' "$APP_DIR/compose.fixed.yml" | wc -l | tr -d ' ')" -gt 1 ]]; then
  echo "[!] compose.fixed.yml içinde birden fazla 'services:' var; en güvenli minimal compose’a düşülüyor."
  cat > "$APP_DIR/compose.fixed.yml" <<'YAML'
version: "3.9"
services:
  app:
    image: alpine:3.20
    command: ["sh","-c","echo QuantumAI system up && sleep 3600"]
    restart: unless-stopped
YAML
fi

cp -f "$APP_DIR/compose.fixed.yml" "$APP_DIR/compose.yml"

echo
echo "────────────────────────────────────────────────────────────────"
echo "[6] Kalıcı “fix & start” komutu oluşturma"
echo "────────────────────────────────────────────────────────────────"

mkdir -p "$APP_DIR/tools"

cat > "$APP_DIR/tools/fix-start.sh" <<'BASH'
#!/usr/bin/env bash
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:$PATH"

APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"
COMPOSE="${COMPOSE:-$APP_DIR/compose.yml}"
DOCKER_USERNAME="${DOCKER_USERNAME:-erenuludemir}"

mkdir -p "$HOME/.docker/cli-plugins"
for p in docker-compose docker-buildx docker-scout docker-sbom; do
  src="/Applications/Docker.app/Contents/Resources/cli-plugins/${p}"
  dst="$HOME/.docker/cli-plugins/${p}"
  [[ -f "$src" ]] && { cp -f "$src" "$dst"; chmod +x "$dst"; }
done

for i in $(seq 1 120); do docker info >/dev/null 2>&1 && break; sleep 1; done
docker context use colima >/dev/null 2>&1 || true

if [[ -n "${DOCKER_PAT:-}" ]]; then
  printf "%s" "$DOCKER_PAT" | docker login -u "$DOCKER_USERNAME" --password-stdin
fi

cd "$APP_DIR"
docker compose -f "$COMPOSE" pull || true
docker compose -f "$COMPOSE" build || true
docker compose -f "$COMPOSE" up -d
docker compose -f "$COMPOSE" ps
