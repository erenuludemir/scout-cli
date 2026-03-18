#!/usr/bin/env bash
# QAI Master Setup: Docker Scout + GitHub Actions + Sysdig + 24/7 Watchdog (macOS, Apple Silicon uyumlu)
# Güvenli: Secret/PAT sadece stdin/env ile; silme YOK, sadece ekleme/yeniden adlandırma.
set -euo pipefail
IFS=$'\n\t'

### =========================== KULLANICI AYARLARI ============================
REGISTRY_HOST="${REGISTRY_HOST:-docker.io}"
REGISTRY_USER_DEFAULT="${REGISTRY_USER_DEFAULT:-erenuludemir}"

# Secrets isimleri (repo seviyesinde yazılır)
SECRET_REG_USER="REGISTRY_USER"
SECRET_REG_TOKEN="REGISTRY_TOKEN"
SECRET_DOCKER_USER="DOCKER_USER"
SECRET_DOCKER_PAT="DOCKER_PAT"
SECRET_SYSDIG_TOKEN="SYSDIG_RISK_TOKEN"   # Sysdig Risk Spotlight API token

# Workflow
WORKFLOW_DIR=".github/workflows"
WORKFLOW_FILE="${WORKFLOW_DIR}/docker-scout.yml"

# Environments
ENV_NAME="${ENV_NAME:-production}"
USE_ENV="${USE_ENV:-1}"          # 1: to-env; 0: to etiketi
TO_IMAGE="${TO_IMAGE:-}"         # doluysa USE_ENV=0

# Colima
COLIMA_PROFILE="${COLIMA_PROFILE:-dev}"
COLIMA_CPU="${COLIMA_CPU:-4}"
COLIMA_MEM="${COLIMA_MEM:-6}"    # GiB
COLIMA_DISK="${COLIMA_DISK:-40}" # GiB

# Otomasyon bayrakları
AUTO_COMMIT="${AUTO_COMMIT:-0}"
AUTO_PUSH="${AUTO_PUSH:-0}"
NON_INTERACTIVE="${NON_INTERACTIVE:-0}"

### ============================== YARDIMCI I/O ===============================
msg(){ printf "\033[1m%s\033[0m\n" "$*"; }
ok(){ printf "✔ %s\n" "$*"; }
warn(){ printf "⚠ %s\n" "$*\n"; }
err(){ printf "\033[31m✖ %s\033[0m\n" "$*" 1>&2; }
pause(){ sleep "${1:-1}"; }

usage(){
  cat <<USAGE
Kullanım: $(basename "$0") [opsiyonlar]
Env değişkenleri (önerilen):
  DOCKER_PAT=***            (zorunlu) Docker Hub PAT
  SYSDIG_RISK_TOKEN=***     (opsiyonel) Sysdig Risk Spotlight token
  GH_TOKEN=ghp_***          (opsiyonel) gh non-interactive login

Opsiyonel env:
  REGISTRY_HOST=docker.io
  REGISTRY_USER_DEFAULT=erenuludemir
  ENV_NAME=production | USE_ENV=0 (to kullan)
  TO_IMAGE=docker.io/erenuludemir/myapp:prod
  NON_INTERACTIVE=1 | AUTO_COMMIT=1 | AUTO_PUSH=1
  COLIMA_PROFILE=dev COLIMA_CPU=4 COLIMA_MEM=6 COLIMA_DISK=40

Örnek:
  DOCKER_PAT='***' SYSDIG_RISK_TOKEN='***' GH_TOKEN='ghp_***' \\
  NON_INTERACTIVE=1 AUTO_COMMIT=1 AUTO_PUSH=1 \\
  TO_IMAGE='docker.io/erenuludemir/myapp:prod' USE_ENV=0 \\
  $(basename "$0")
USAGE
}

### ============================= ÖN KONTROLLER ===============================
[ -d .git ] || { err "Bu komutu hedef REPO kökünde çalıştırın ('.git' yok)."; exit 1; }

# Oturum bazlı limit + TMP yönlendirme (SİLME YOK)
ulimit -n 65536 2>/dev/null || true
ulimit -u 4096  2>/dev/null || true
export TMPDIR="${TMPDIR:-$HOME/.tmp_qai}"
export GIT_TMPDIR="$TMPDIR"
export HOMEBREW_CACHE="${HOMEBREW_CACHE:-$HOME/Library/Caches/Homebrew}"
mkdir -p "$TMPDIR" "$HOMEBREW_CACHE" 2>/dev/null || true

msg "Disk durumu (home & tmp):"
df -h "$HOME" "$TMPDIR" | awk 'NR==1 || /Users|\.tmp_qai/ {print}'

# Homebrew
if ! command -v brew >/dev/null 2>&1; then
  err "Homebrew yok. Kurulum: https://brew.sh (manuel kurup komutu tekrar çalıştır.)"
  exit 1
fi
export HOMEBREW_FORCE_BREWED_CURL=1 HOMEBREW_NO_INSTALL_CLEANUP=1 HOMEBREW_NO_ENV_HINTS=1

# curl
if ! command -v curl >/dev/null 2>&1; then
  msg "curl yok → brew ile kurulum…"; brew list curl >/dev/null 2>&1 || brew install curl
fi
[ -d "/opt/homebrew/opt/curl/bin" ] && export PATH="/opt/homebrew/opt/curl/bin:$PATH"

# gh
if ! command -v gh >/dev/null 2>&1; then
  msg "gh yok → brew ile kurulum…"
  brew install gh || { warn "gh install tekrar denenecek…"; pause 2; brew install gh; }
fi
# gh login
if ! gh auth status >/dev/null 2>&1; then
  if [ "${NON_INTERACTIVE}" = "1" ]; then
    [ -n "${GH_TOKEN:-}" ] || { err "NON_INTERACTIVE=1 için GH_TOKEN gerekli."; exit 1; }
    printf "%s" "$GH_TOKEN" | gh auth login --with-token
  else
    msg "gh auth login başlatılıyor…"; gh auth login
  fi
fi
ok "GitHub CLI hazır."

# docker CLI
if ! command -v docker >/dev/null 2>&1; then
  warn "docker CLI yok gibi görünüyor. brew reinstall docker deneyebilirsin. Devam ediyorum (Actions etkilenmez)."
fi

### ====================== REGISTRY USER + PAT ALIMI ==========================
REGISTRY_USER="${REGISTRY_USER_DEFAULT}"
if [ "${NON_INTERACTIVE}" != "1" ]; then
  read -r -p "Docker Hub kullanıcı adı [${REGISTRY_USER}]: " _in || true
  [ -n "${_in:-}" ] && REGISTRY_USER="$_in"
fi
ok "Kullanıcı: ${REGISTRY_USER}"

[ -n "${DOCKER_PAT:-}" ] || {
  if [ "${NON_INTERACTIVE}" = "1" ]; then err "DOCKER_PAT boş olamaz."; exit 1; fi
  printf "Docker Hub PAT (görünmez): "; stty -echo; read -r DOCKER_PAT || true; stty echo; printf "\n"
}
[ -n "${DOCKER_PAT:-}" ] || { err "PAT boş olamaz."; exit 1; }

# Sysdig token opsiyonel
if [ -z "${SYSDIG_RISK_TOKEN:-}" ] && [ "${NON_INTERACTIVE}" != "1" ]; then
  printf "Sysdig Risk Spotlight Token (boş bırakılabilir): "
  stty -echo; read -r SYSDIG_RISK_TOKEN || true; stty echo; printf "\n"
fi

### ======================== REPO SECRETS YAZIMI ==============================
REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner)
msg "Secrets ekleniyor → ${REPO_FULL}"
printf "%s" "$REGISTRY_USER" | gh secret set "${SECRET_REG_USER}"    --repo "${REPO_FULL}" --body -
printf "%s" "$DOCKER_PAT"    | gh secret set "${SECRET_REG_TOKEN}"   --repo "${REPO_FULL}" --body -
printf "%s" "$REGISTRY_USER" | gh secret set "${SECRET_DOCKER_USER}" --repo "${REPO_FULL}" --body -
printf "%s" "$DOCKER_PAT"    | gh secret set "${SECRET_DOCKER_PAT}"  --repo "${REPO_FULL}" --body -
if [ -n "${SYSDIG_RISK_TOKEN:-}" ]; then
  printf "%s" "$SYSDIG_RISK_TOKEN" | gh secret set "${SECRET_SYSDIG_TOKEN}" --repo "${REPO_FULL}" --body -
  ok "Sysdig token secret yazıldı."
else
  warn "Sysdig token verilmedi; sonradan 'gh secret set ${SECRET_SYSDIG_TOKEN}' ile ekleyebilirsin."
fi
ok "Docker secrets yazıldı."

### ==================== GITHUB ENVIRONMENT (isteğe bağlı) ====================
if [ -z "${TO_IMAGE}" ]; then USE_ENV=1; fi
if [ "${USE_ENV}" = "1" ]; then
  msg "Environment idempotent oluşturuluyor: ${ENV_NAME}"
  gh api --method PUT -H "Accept: application/vnd.github+json" \
    "/repos/${REPO_FULL}/environments/${ENV_NAME}" -f wait_timer=0 >/dev/null || true
  ok "Environment hazır."
fi

### ===================== WORKFLOW OLUŞTURMA (idempotent) =====================
mkdir -p "${WORKFLOW_DIR}"
if [ "${USE_ENV}" = "1" ]; then
  COMPARE_TARGET="to-env: ${ENV_NAME}"
else
  COMPARE_TARGET="to: ${TO_IMAGE}"
fi

read -r -d '' SYSDIG_STEP <<'YAML' || true
      - name: Sysdig Risk Spotlight | token export (optional)
        if: ${{ github.event_name == 'pull_request' && secrets.SYSDIG_RISK_TOKEN != '' }}
        env:
          SYSDIG_RISK_TOKEN: ${{ secrets.SYSDIG_RISK_TOKEN }}
        run: |
          echo "Sysdig token mevcut. 3rd-party entegrasyon adımında bu ENV kullanılacak."
YAML

cat > "${WORKFLOW_FILE}" <<YAML
name: Docker + Scout PR Compare

on:
  push:
    tags: ["*"]
    branches:
      - "main"
  pull_request:
    branches: ["**"]

env:
  REGISTRY: ${REGISTRY_HOST}
  IMAGE_NAME: \${{ github.repository }}
  SHA: \${{ github.event.pull_request.head.sha || github.event.after }}

jobs:
  build-and-compare:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Authenticate to registry \${{ env.REGISTRY }}
        uses: docker/login-action@v3
        with:
          registry: \${{ env.REGISTRY }}
          username: \${{ secrets.${SECRET_REG_USER} }}
          password: \${{ secrets.${SECRET_REG_TOKEN} }}

      - name: Setup Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: \${{ env.REGISTRY }}/\${{ env.IMAGE_NAME }}
          labels: |
            org.opencontainers.image.revision=\${{ env.SHA }}
          tags: |
            type=edge,branch=\$repo.default_branch
            type=semver,pattern=v{{version}}
            type=sha,prefix=,suffix=,format=short

      - name: Build (PR: load, Push: push)
        id: build-and-push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: \${{ github.event_name != 'pull_request' }}
          load: \${{ github.event_name == 'pull_request' }}
          tags: \${{ steps.meta.outputs.tags }}
          labels: \${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          sbom: \${{ github.event_name != 'pull_request' }}
          provenance: \${{ github.event_name != 'pull_request' }}

      - name: Authenticate to Docker (optional)
        if: \${{ github.event_name == 'pull_request' }}
        uses: docker/login-action@v3
        with:
          username: \${{ secrets.${SECRET_DOCKER_USER} || secrets.${SECRET_REG_USER} }}
          password: \${{ secrets.${SECRET_DOCKER_PAT}  || secrets.${SECRET_REG_TOKEN} }}

      - name: Docker Scout Compare
        if: \${{ github.event_name == 'pull_request' }}
        uses: docker/scout-action@v1
        with:
          command: compare
          image: \${{ steps.meta.outputs.tags }}
          ${COMPARE_TARGET}
          ignore-unchanged: true
          only-severities: critical,high
          github-token: \${{ secrets.GITHUB_TOKEN }}

${SYSDIG_STEP}

      - name: Docker Scout CVEs → SARIF
        if: \${{ github.event_name == 'pull_request' }}
        id: cves
        uses: docker/scout-action@v1
        with:
          command: cves
          image: \${{ steps.meta.outputs.tags }}
          sarif-file: scout-cves.sarif
          only-severities: critical,high

      - name: Upload SARIF
        if: \${{ github.event_name == 'pull_request' }}
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: scout-cves.sarif
YAML
ok "Workflow yazıldı → ${WORKFLOW_FILE}"

### =============== Docker Scout CLI (plugin) Kurulum Sağlama ==================
# 1) Yerelde zaten varsa (senin tree: scout-cli-1.18.3/install.sh) onu kullan
SCOUT_LOCAL_DIR="$HOME/Documents/GitHub/scout-cli-1.18.3"
if [ -x "${SCOUT_LOCAL_DIR}/install.sh" ]; then
  msg "Local Docker Scout installer bulundu → ${SCOUT_LOCAL_DIR}/install.sh"
  bash "${SCOUT_LOCAL_DIR}/install.sh" || warn "Local installer hata verdi; online installer denenebilir."
else
  warn "Local installer bulunamadı; online script ile denenebilir:"
  warn "curl -sSfL https://raw.githubusercontent.com/docker/scout-cli/main/install.sh | sh -s --"
fi

# macOS Gatekeeper engeline karşı yetkilendir
if [ -f "$HOME/.docker/cli-plugins/docker-scout" ]; then
  chmod +x "$HOME/.docker/cli-plugins/docker-scout" || true
  xattr -d com.apple.quarantine "$HOME/.docker/cli-plugins/docker-scout" 2>/dev/null || true
  ok "docker-scout plugin hazır görünüyor."
else
  warn "docker-scout plugin henüz görünmüyor; yukarıdaki installer komutunu tekrar çalıştırabilirsin."
fi

### ================= Colima / Docker Desktop Oto-Kurtarma ====================
# Colima & qemu kurulu mu?
if ! command -v colima >/dev/null 2>&1; then
  msg "colima yok → brew ile kurulum…"; brew list colima >/dev/null 2>&1 || brew install colima
fi
if ! command -v qemu-img >/dev/null 2>&1; then
  msg "qemu yok → brew ile kurulum…"; brew list qemu >/dev/null 2>&1 || brew install qemu
fi

# Yeni profil (SHRINK deneme yok, doğrudan disk=40G)
msg "Colima '${COLIMA_PROFILE}' profili başlatılıyor (disk=${COLIMA_DISK}G)…"
if ! colima status --profile "${COLIMA_PROFILE}" >/dev/null 2>&1; then
  colima start --profile "${COLIMA_PROFILE}" --runtime docker \
    --cpu "${COLIMA_CPU}" --memory "${COLIMA_MEM}" --disk "${COLIMA_DISK}" || warn "Colima start uyarı aldı."
else
  colima start --profile "${COLIMA_PROFILE}" || warn "Colima zaten çalışıyor veya başlatılamadı."
fi

# Context geçiş
if docker context create "colima-${COLIMA_PROFILE}" --docker "host=unix://$HOME/.colima/${COLIMA_PROFILE}/docker.sock" 2>/dev/null; then
  ok "Context oluşturuldu: colima-${COLIMA_PROFILE}"
fi
docker context use "colima-${COLIMA_PROFILE}" 2>/dev/null || docker context use colima 2>/dev/null || true

# Eğer daemon yoksa, Desktop'a dönmeyi dene
if ! docker info >/dev/null 2>&1; then
  warn "Colima daemon erişilemiyor; Docker Desktop 'default' context deneniyor…"
  docker context use default 2>/dev/null || true
fi

### =================== Yerel docker login (opsiyonel) ========================
if command -v docker >/dev/null 2>&1; then
  if echo "test" | docker version >/dev/null 2>&1; then true; fi
  printf "%s" "$DOCKER_PAT" | docker login -u "${REGISTRY_USER}" --password-stdin "${REGISTRY_HOST}" >/dev/null 2>&1 || \
    warn "Yerel docker login başarısız olabilir; Actions tarafı etkilenmez."
fi

### ================== 24/7 WATCHDOG (launchd, idempotent) ====================
# Her 5 dakikada bir: docker daemon up? değilse colima profile start, değilse default context’e dön.
WATCH_DIR="$HOME/.qai/watchdog"
WATCH_SCRIPT="${WATCH_DIR}/docker_watchdog.sh"
PLIST="$HOME/Library/LaunchAgents/com.eren.scout.watchdog.plist"

mkdir -p "$WATCH_DIR"
cat > "$WATCH_SCRIPT" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
PROFILE="${COLIMA_PROFILE:-dev}"
CTX_COLIMA="colima-${PROFILE}"
SOCK="$HOME/.colima/${PROFILE}/docker.sock"

# Soket var mı ve docker info dönüyor mu?
if [ -S "${SOCK}" ]; then
  if DOCKER_HOST="unix://${SOCK}" docker info >/dev/null 2>&1; then
    exit 0
  fi
fi

# Değilse: colima start dener; olmazsa default context
if command -v colima >/dev/null 2>&1; then
  colima start --profile "${PROFILE}" >/dev/null 2>&1 || true
fi
docker context use "${CTX_COLIMA}" >/dev/null 2>&1 || docker context use colima >/dev/null 2>&1 || docker context use default >/dev/null 2>&1 || true
exit 0
SH
chmod +x "$WATCH_SCRIPT"

cat > "$PLIST" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key><string>com.eren.scout.watchdog</string>
    <key>ProgramArguments</key>
    <array>
      <string>/bin/bash</string>
      <string>${WATCH_SCRIPT}</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
      <key>COLIMA_PROFILE</key><string>${COLIMA_PROFILE}</string>
    </dict>
    <key>StartInterval</key><integer>300</integer>
    <key>RunAtLoad</key><true/>
    <key>StandardOutPath</key><string>${WATCH_DIR}/out.log</string>
    <key>StandardErrorPath</key><string>${WATCH_DIR}/err.log</string>
  </dict>
</plist>
PL

launchctl unload "$PLIST" >/dev/null 2>&1 || true
launchctl load  "$PLIST" >/dev/null 2>&1 || true
ok "24/7 watchdog aktif (5 dk aralık)."

### =================== GIT ADD/COMMIT/PUSH (opsiyonel) =======================
if [ "${AUTO_COMMIT}" = "1" ]; then
  git add "${WORKFLOW_FILE}"
  if ! git diff --cached --quiet; then
    git commit -m "ci: add/refresh Docker Scout PR compare workflow (+ Sysdig + watchdog)"
    ok "Commit tamam."
  else
    ok "Commit edecek değişiklik yok."
  fi
  if [ "${AUTO_PUSH}" = "1" ]; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    git push -u origin "${CURRENT_BRANCH}" || warn "Push yapılamadı."
    ok "Push denendi."
  fi
else
  msg "Workflow oluşturuldu; commit/push SENİN kontrolünde."
fi

ok "QAI Master Setup TAMAMLANDI. (silme yok, her şey idempotent)"
