#!/bin/bash
set -e
echo "[⭐] QuantumAI - Colima + DevContainer Auto-Setup Başlıyor"

# — 1) PATH’i düzelt (geçici)
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# — 2) Limitleri arttır
ulimit -n 65536
ulimit -u 2048

# — 3) Cache / TMP temizliği (silmesiz)
mkdir -p "$HOME/.colima/tmp"
export TMPDIR="$HOME/.colima/tmp"

# — 4) Colima önbelleğini temizle
rm -rf "$HOME/Library/Caches/colima" || true

# — 5) Eski Colima'yi durdur-sil
colima stop || true
colima delete -f || true

# — 6) Yeni Colima instance başlat
colima start --runtime docker --cpu 4 --memory 6 --disk 40 --mount-type virtiofs

# — 7) Terminali Colima context’e çek
docker context use colima

# — 8) Smoke test
docker info
docker run --rm hello-world

# — 9) Dev Container başlat (VSCode içinde)
echo "[🚀] Artık VS Code'da 'Reopen in Container' ile ortam hazır"
