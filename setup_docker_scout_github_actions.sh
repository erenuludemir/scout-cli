#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

REGISTRY_USER_DEFAULT="erenuludemir"
REGISTRY_HOST="${REGISTRY_HOST:-docker.io}"

SECRET_REG_USER="REGISTRY_USER"
SECRET_REG_TOKEN="REGISTRY_TOKEN"
SECRET_DOCKER_USER="DOCKER_USER"
SECRET_DOCKER_PAT="DOCKER_PAT"
SECRET_SYSDIG_TOKEN="SYSDIG_RISK_TOKEN"

WORKFLOW_DIR=".github/workflows"
WORKFLOW_FILE="${WORKFLOW_DIR}/docker-scout.yml"

ENV_NAME="production"
USE_ENV=1
TO_IMAGE=""

AUTO_COMMIT=0
AUTO_PUSH=0
NON_INTERACTIVE=0
REGISTRY_USER="${REGISTRY_USER_DEFAULT}"

msg(){ printf "\033[1m%s\033[0m\n" "$*"; }
ok(){ printf "✔ %s\n" "$*"; }
warn(){ printf "⚠ %s\n" "$*\n"; }
err(){ printf "\033[31m✖ %s\033[0m\n" "$*" 1>&2; }

usage(){
  cat <<USAGE
Kullanım: $(basename "$0") [seçenekler]

Seçenekler:
  --to <image:tag>          Compare hedef etiketi (örn: docker.io/kullanici/app:prod).
  --env-name <name>         Scout environment adı (vars: production).
  --no-env                  Environment oluşturma adımını atla (yalnızca 'to:' kullan).
  --registry-user <name>    Registry kullanıcı adı (vars: ${REGISTRY_USER_DEFAULT}).
  --registry-host <host>    Registry host (vars: docker.io).
  --auto-commit             Workflow'u otomatik commit et.
  --auto-push               Commit sonrası otomatik push et.
  --non-interactive         Prompt sorma; DOCKER_PAT ve (gerekirse) GH_TOKEN gerekli.
  -h, --help                Bu yardımı göster.

Gizli değişkenler (env ile verilebilir):
  DOCKER_PAT                Docker Hub PAT (zorunlu)
  SYSDIG_RISK_TOKEN         Sysdig Risk Spotlight API Token (opsiyonel ama önerilir)
  GH_TOKEN                  gh non-interactive login için Personal Access Token (opsiyonel)

Örnek:
  DOCKER_PAT='***' GH_TOKEN='ghp_***' $(basename "$0") \
    --to docker.io/erenuludemir/myapp:prod --auto-commit --auto-push --non-interactive
USAGE
}

while (( "$#" )); do
  case "${1:-}" in
    --to)                 TO_IMAGE="${2:-}"; USE_ENV=0; shift 2;;
    --env-name)           ENV_NAME="${2:-}"; shift 2;;
    --no-env)             USE_ENV=0; shift 1;;
    --registry-user)      REGISTRY_USER="${2:-}"; shift 2;;
    --registry-host)      REGISTRY_HOST="${2:-}"; shift 2;;
    --auto-commit)        AUTO_COMMIT=1; shift 1;;
    --auto-push)          AUTO_PUSH=1; shift 1;;
    --non-interactive)    NON_INTERACTIVE=1; shift 1;;
    -h|--help)            usage; exit 0;;
    *)                    err "Bilinmeyen argüman: $1"; usage; exit 2;;
  esac
done

if [ ! -d .git ]; then
  err "Bu komutu bir Git deposunun kökünde çalıştırın. ('.git' bulunamadı)"
  exit 1
fi

ulimit -n 65536 2>/dev/null || true
ulimit -u 4096  2>/dev/null || true
export TMPDIR="${TMPDIR:-$HOME/.tmp_qai}"
export GIT_TMPDIR="$TMPDIR"
export HOMEBREW_CACHE="${HOMEBREW_CACHE:-$HOME/Library/Caches/Homebrew}"
mkdir -p "$TMPDIR" "$HOMEBREW_CACHE" 2>/dev/null || true

msg "Disk durumu:"
df -h "$HOME" "$TMPDIR" | awk 'NR==1 || /Users|\.tmp_qai/ {print}'

export HOMEBREW_FORCE_BREWED_CURL=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ENV_HINTS=1

if ! command -v brew >/dev/null 2>&1; then
  err "Homebrew bulunamadı. Kurulum: https://brew.sh"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  msg "curl bulunamadı, Homebrew ile kurulacak…"
  brew list curl >/dev/null 2>&1 || brew install curl
fi
[ -d "/opt/homebrew/opt/curl/bin" ] && export PATH="/opt/homebrew/opt/curl/bin:$PATH"

if ! command -v gh >/dev/null 2>&1; then
  msg "gh (GitHub CLI) kuruluyor…"
  brew install gh || { warn "brew install gh tekrar deneniyor…"; sleep 2; brew install gh; }
  ok "gh kuruldu."
fi

if ! gh auth status >/dev/null 2>&1; then
  if [ "$NON_INTERACTIVE" -eq 1 ]; then
    if [ -n "${GH_TOKEN:-}" ]; then
      printf "%s" "$GH_TOKEN" | gh auth login --with-token
    else
      err "NON-INTERACTIVE modda gh oturumu yok. GH_TOKEN sağlamalısın."
      exit 1
    fi
  else
    msg "GitHub CLI oturumu yok. gh auth login başlatılıyor…"
    gh auth login
  fi
fi
ok "GitHub CLI oturumu hazır."

if ! command -v docker >/dev/null 2>&1; then
  warn "docker CLI bulunamadı. Actions tarafı etkilenmez; yerel login/test atlanacak."
fi

read_user(){
  local prompt="$1" default="$2" out
  if [ "$NON_INTERACTIVE" -eq 1 ]; then
    printf "%s\n" "$default"
  else
    read -r -p "${prompt} [${default}]: " out || true
    if [ -z "${out:-}" ]; then printf "%s\n" "$default"; else printf "%s\n" "$out"; fi
  fi
}

REGISTRY_USER="$(read_user 'Docker Hub kullanıcı adı' "${REGISTRY_USER}")"
ok "Kullanıcı: ${REGISTRY_USER}"

if [ -z "${DOCKER_PAT:-}" ]; then
  if [ "$NON_INTERACTIVE" -eq 1 ]; then
    err "NON-INTERACTIVE modda DOCKER_PAT zorunludur."
    exit 1
  else
    printf "Docker Hub PAT (görünmez): "
    stty -echo; read -r DOCKER_PAT || true; stty echo; printf "\n"
  fi
fi
[ -n "${DOCKER_PAT:-}" ] || { err "PAT boş olamaz."; exit 1; }

if [ -z "${SYSDIG_RISK_TOKEN:-}" ] && [ "$NON_INTERACTIVE" -eq 0 ]; then
  printf "Sysdig Risk Spotlight Token (boş bırakılabilir): "
  stty -echo; read -r SYSDIG_RISK_TOKEN || true; stty echo; printf "\n"
fi

REPO_FULL=$(gh repo view --json nameWithOwner -q .nameWithOwner)
msg "Secrets ekleniyor → ${REPO_FULL}"
printf "%s" "$REGISTRY_USER"   | gh secret set "${SECRET_REG_USER}"    --repo "${REPO_FULL}" --body -
printf "%s" "$DOCKER_PAT"      | gh secret set "${SECRET_REG_TOKEN}"   --repo "${REPO_FULL}" --body -
printf "%s" "$REGISTRY_USER"   | gh secret set "${SECRET_DOCKER_USER}" --repo "${REPO_FULL}" --body -
printf "%s" "$DOCKER_PAT"      | gh secret set "${SECRET_DOCKER_PAT}"  --repo "${REPO_FULL}" --body -
if [ -n "${SYSDIG_RISK_TOKEN:-}" ]; then
  printf "%s" "$SYSDIG_RISK_TOKEN" | gh secret set "${SECRET_SYSDIG_TOKEN}" --repo "${REPO_FULL}" --body -
  ok "Sysdig token secret eklendi: ${SECRET_SYSDIG_TOKEN}"
else
  warn "Sysdig token verilmedi; entegrasyon adımı secret olmadan yazılacak (sonradan ekleyebilirsin)."
fi
ok "Docker secrets yazıldı."

if [ "$USE_ENV" -eq 1 ]; then
  msg "${ENV_NAME} environment oluştur/yenile (idempotent)…"
  gh api --method PUT \
    -H "Accept: application/vnd.github+json" \
    "/repos/${REPO_FULL}/environments/${ENV_NAME}" \
    -f wait_timer=0 >/dev/null || true
  ok "Environment hazır: ${ENV_NAME}"
else
  warn "--to kullanıldığı için environment oluşturma atlandı."
fi

msg "Workflow dosyası yazılıyor → ${WORKFLOW_FILE}"
mkdir -p "${WORKFLOW_DIR}"

if [ "$USE_ENV" -eq 1 ]; then
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

ok "Workflow dosyası yazıldı."

if command -v docker >/dev/null 2>&1; then
  if [ "$NON_INTERACTIVE" -eq 1 ]; then
    warn "Yerel docker login atlandı (non-interactive). Actions etkilenmez."
  else
    msg "İsteğe bağlı: yerel Docker login (enter=atla)"
    read -r -p "Yerelde docker login yapılsın mı? [y/N]: " ans || true
    if [[ "${ans:-}" =~ ^[Yy]$ ]]; then
      printf "%s" "$DOCKER_PAT" | docker login -u "${REGISTRY_USER}" --password-stdin "${REGISTRY_HOST}" || warn "Yerel docker login başarısız (Actions etkilenmez)."
    fi
  fi
fi

if [ "$AUTO_COMMIT" -eq 1 ]; then
  git add "${WORKFLOW_FILE}"
  if ! git diff --cached --quiet; then
    git commit -m "ci: add/refresh Docker Scout PR compare workflow (+ Sysdig token export)"
    ok "Commit tamam."
  else
    ok "Commit edilecek değişiklik yok."
  fi
  if [ "$AUTO_PUSH" -eq 1 ]; then
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    git push -u origin "${CURRENT_BRANCH}"
    ok "Push tamam."
  fi
else
  msg "Workflow dosyası oluşturuldu; commit/push SENİN kontrolünde."
fi

ok "Kurulum tamamlandı."
