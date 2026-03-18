#!/usr/bin/env bash
set -euo pipefail

ORG="erenuludemir"
APP="scout-cli"
REPO="$ORG/$APP"

if [[ "$ORG" == "erenuludemir" ]]; then
  echo "[!] Lütfen betiğe başlamadan ORG değişkenini kendi Docker Hub adınızla doldurun."; exit 1
fi

echo "[i] Ortam temizleniyor…"
unset DOCKER_HOST || true
colima stop >/dev/null 2>&1 || true
colima delete -f >/dev/null 2>&1 || true
rm -rf ~/.colima ~/.lima 2>/dev/null || true
rm -rf ~/Library/Containers/com.docker.docker \
       ~/Library/Group\ Containers/group.com.docker \
       ~/Library/Caches/com.docker.docker 2>/dev/null || true

brew cleanup -s >/dev/null 2>&1 || true
rm -rf ~/Library/Caches/* 2>/dev/null || true

echo "[i] Boş alan:"
df -h /System/Volumes/Data || true

echo "[i] Colima (qemu) başlatılıyor…"
colima start --vm-type qemu --cpu 4 --memory 6 --disk 40

docker context use colima >/dev/null

echo "[i] Docker daemon bekleniyor…"
for i in $(seq 1 30); do
  if docker info >/dev/null 2>&1; then
    echo "[OK] Docker daemon hazır."; break
  fi
  sleep 1
  [[ $i -eq 30 ]] && { echo "[!] Docker daemon gelmedi."; exit 1; }
done


echo "[i] Demo repo klonlanıyor…"
rm -rf scout-demo-service 2>/dev/null || true
git clone gh repo clone erenuludemir/scout-cli
cd scout-cli-service

echo "[i] Docker Hub login (gerekirse şifre sorar)…"
docker login

echo "[i] İlk imaj (v1) derleniyor ve push ediliyor…"
docker build --push -t "$REPO:v1" .

echo "[i] Docker Scout enroll & repo enable…"
docker scout enroll "$ORG" || true
docker scout repo enable --org "$ORG" "$REPO" || true

echo "[i] Express zafiyetleri:"
docker scout cves --only-package express || true


echo "[i] package.json güncelleniyor (express 4.17.3)…"
if grep -q '"express": "4.17.1"' package.json 2>/dev/null; then
  sed -i '' 's/"express": "4.17.1"/"express": "4.17.3"/' package.json
fi
docker build --push -t "$REPO:v2" .

echo "[i] v2 için express zafiyet taraması:"
docker scout cves --only-package express || true

echo "[i] Organization set ve quickview:"
docker scout config organization "$ORG"
docker scout quickview || true

echo "[i] v3 (SBOM + provenance) derleniyor ve push ediliyor…"
docker build --provenance=true --sbom=true --push -t "$REPO:v3" .

echo
echo "────────────────────────────────────────"
echo "✔ Bitti. İncelemek için:"
echo "  - CVE’ler:      docker scout cves $REPO:v3"
echo "  - Quickview:    docker scout quickview --ref $REPO:v3"
echo "  - Dashboard:    https://scout.docker.com/ (Images bölümünden $REPO)"
echo "────────────────────────────────────────"
