#!/usr/bin/env bash
set -Eeuo pipefail
export LANG=C LC_ALL=C

# ================== KULLANICI DEĞİŞKENLERİ ==================
APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"
ENV_FILE="$APP_DIR/.env"
DB_CTR="quantumai-db"
DB_PORT_HOST="${DB_PORT_HOST:-5435}"
GLI_IMAGE="${GLI_IMAGE:-erenuludemir/gli-app:latest}"
GLI_CTR="${GLI_CTR:-gli-container}"
HOST_PORT="${HOST_PORT:-5003}"     # .env ile senkronlar
COLIMA_PROFILE="${COLIMA_PROFILE:-default}"
RETRIES=3
SLEEP_BETWEEN=6
# ============================================================

echo "──────────────────────────────────────────────────────────────"
echo "[0] Önkoşullar & PATH"
echo "──────────────────────────────────────────────────────────────"
mkdir -p "$APP_DIR" "$HOME/bin"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ Gerekli komut eksik: $1"; exit 1; }; }
need bash; need curl
command -v jq >/dev/null 2>&1 || echo "ℹ️ jq yok (opsiyonel)."

if ! command -v docker >/dev/null 2>&1; then
  echo "❌ docker yok. Yükleyin: brew install docker"
  exit 1
fi
if ! command -v colima >/dev/null 2>&1; then
  echo "❌ colima yok. Yükleyin: brew install colima"
  exit 1
fi

echo "──────────────────────────────────────────────────────────────"
echo "[1] Colima durumu & başlatma"
echo "──────────────────────────────────────────────────────────────"
if ! colima status | grep -q "Running"; then
  echo "ℹ️ Colima başlatılıyor (cpu=4, mem=6GiB, disk=60GiB)…"
  colima start --cpu 4 --memory 6 --disk 60 || {
    echo "⚠️ colima start başarısız. 'colima start --edit' ile kaynakları artırıp tekrar deneyin."
    colima start --edit
    exit 1
  }
else
  echo "✅ Colima çalışıyor."
fi

echo "──────────────────────────────────────────────────────────────"
echo "[2] containerd content store onarımı (rename/no such file)"
echo "──────────────────────────────────────────────────────────────"
colima ssh -- "sudo bash -s" <<'EOF'
set -Eeuo pipefail
mkdir -p /var/lib/containerd/io.containerd.content.v1.content/ingest
# 1 günden eski yarım kalan ingest klasörlerini temizle (güvenli)
find /var/lib/containerd/io.containerd.content.v1.content/ingest \
  -mindepth 1 -maxdepth 1 -type d -mtime +1 -print -exec rm -rf {} + || true
# dangling image/layer prune
nerdctl system prune -af || true
EOF
echo "✅ Content store onarım tamam."

echo "──────────────────────────────────────────────────────────────"
echo "[3] Python venv & pip"
echo "──────────────────────────────────────────────────────────────"
PY_BIN="$(command -v python3 || true)"
if [[ -z "${PY_BIN}" ]]; then
  echo "❌ python3 yok. brew install python"
  exit 1
fi
if [[ ! -d "$APP_DIR/.venv" ]]; then
  "$PY_BIN" -m venv "$APP_DIR/.venv"
fi
VENV_BIN="$APP_DIR/.venv/bin"
"$PY_BIN" -m ensurepip --upgrade || true
"$VENV_BIN/python" -m ensurepip --upgrade || true
# get-pip.py varsa, çalıştırılabilir olmasa bile python ile çağır
if [[ -f "$APP_DIR/get-pip.py" ]]; then
  "$VENV_BIN/python" "$APP_DIR/get-pip.py" || true
fi
"$VENV_BIN/python" -m pip install --upgrade pip wheel setuptools || true

echo "──────────────────────────────────────────────────────────────"
echo "[4] .env senkronizasyonu (ETH_SENDER_ADDRESS doldur)"
echo "──────────────────────────────────────────────────────────────"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ .env bulunamadı: $ENV_FILE"
  exit 1
fi

# HOST_PORT .env içinde varsa onu baz al
HOST_PORT_ENV="$(grep -E '^HOST_PORT=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
if [[ -n "${HOST_PORT_ENV:-}" ]]; then HOST_PORT="$HOST_PORT_ENV"; fi

# ETH_SENDER_ADDRESS boş ve WALLET_ADDRESS doluysa: silmeden yeni satır ekle
if grep -q '^ETH_SENDER_ADDRESS=$' "$ENV_FILE" && grep -q '^WALLET_ADDRESS=' "$ENV_FILE"; then
  WA="$(grep '^WALLET_ADDRESS=' "$ENV_FILE" | head -n1 | cut -d= -f2-)"
  if [[ -n "${WA:-}" ]]; then
    echo "ℹ️ ETH_SENDER_ADDRESS boş → WALLET_ADDRESS ile dolduruluyor: $WA"
    cp -p "$ENV_FILE" "$ENV_FILE.bak.$(date +%Y%m%d_%H%M%S)"
    awk -v wa="$WA" '
      BEGIN{added=0}
      {print}
      /^ETH_SENDER_ADDRESS=$/ && added==0 {print "ETH_SENDER_ADDRESS=" wa; added=1}
    ' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
  fi
fi

echo "──────────────────────────────────────────────────────────────"
echo "[5] Postgres (quantumai-db) başlat/sağlık kontrolü"
echo "──────────────────────────────────────────────────────────────"
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CTR}\$"; then
  docker rm -f "$DB_CTR" >/dev/null 2>&1 || true
  docker run -d --name "$DB_CTR" -e POSTGRES_PASSWORD=postgres -p "${DB_PORT_HOST}:5432" postgres:16-alpine
fi
for i in $(seq 1 20); do
  if docker logs "$DB_CTR" 2>&1 | grep -qi "database system is ready to accept connections"; then
    echo "✅ DB hazır."
    break
  fi
  echo "… DB bekleniyor ($i/20)"; sleep 1
done

echo "──────────────────────────────────────────────────────────────"
echo "[6] GLI image çek & container başlat (retry)"
echo "──────────────────────────────────────────────────────────────"
pull_ok=0
for i in $(seq 1 "$RETRIES"); do
  if docker pull "$GLI_IMAGE"; then pull_ok=1; break; fi
  echo "⚠️ Pull denemesi ($i/$RETRIES) hata verdi, ${SLEEP_BETWEEN}s sonra tekrar…"
  sleep "$SLEEP_BETWEEN"
  colima ssh -- "sudo nerdctl image prune -f" || true
done
if [[ "$pull_ok" -ne 1 ]]; then
  echo "❌ Image çekilemedi: $GLI_IMAGE"
  exit 1
fi

docker rm -f "$GLI_CTR" >/dev/null 2>&1 || true
docker run -d --name "$GLI_CTR" --env-file "$ENV_FILE" -p "${HOST_PORT}:5003" "$GLI_IMAGE"

echo "──────────────────────────────────────────────────────────────"
echo "[7] Healthcheck → http://127.0.0.1:${HOST_PORT}/"
echo "──────────────────────────────────────────────────────────────"
ok=0
for i in $(seq 1 25); do
  if curl -fsS "http://127.0.0.1:${HOST_PORT}/" >/dev/null 2>&1; then ok=1; break; fi
  printf "."; sleep 1
done
echo
if [[ "$ok" -eq 1 ]]; then
  echo "✅ Uygulama ayakta: http://127.0.0.1:${HOST_PORT}/"
else
  echo "⚠️ Healthcheck başarısız (port ${HOST_PORT}). Son 200 log satırı:"
  docker logs --tail 200 "$GLI_CTR" || true
fi

echo "──────────────────────────────────────────────────────────────"
echo "[8] Notlar"
echo "──────────────────────────────────────────────────────────────"
echo "• JSON dosyaları komut değildir; görüntülemek için:"
echo "    less \"$APP_DIR/history_2024-10-06T05_41_56.279+03_00.json\""
echo "• get-pip.py yürütülebilir olmasa bile python ile çağrıldı."
echo "• Docker Desktop gerekmez; Colima ile çalışıyoruz."
echo "• containerd rename/no-such-file sorunu için Colima içi onarım uygulandı."
echo
echo "Tamamlandı ✅"
