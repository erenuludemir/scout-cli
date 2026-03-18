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
HOST_PORT="${HOST_PORT:-5003}"     # .env ile senkronlanır
COLIMA_PROFILE="${COLIMA_PROFILE:-default}"
RETRIES=3
SLEEP_BETWEEN=6
# ============================================================

say() { printf '%s\n' "$*"; }
need() { command -v "$1" >/dev/null 2>&1 || { say "❌ Gerekli komut eksik: $1"; exit 1; }; }

say "──────────────────────────────────────────────────────────────"
say "[0] Önkoşullar & PATH"
say "──────────────────────────────────────────────────────────────"
mkdir -p "$APP_DIR" "$HOME/bin"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
need bash; need curl
command -v jq >/dev/null 2>&1 || say "ℹ️ jq yok (opsiyonel)."

if ! command -v docker >/dev/null 2>&1; then
  say "❌ docker yok. Yükleyin: brew install docker"
  exit 1
fi
if ! command -v colima >/dev/null 2>&1; then
  say "❌ colima yok. Yükleyin: brew install colima"
  exit 1
fi

say "──────────────────────────────────────────────────────────────"
say "[0.1] SSH config uyumluluk yamasi (satır silmeden)"
say "──────────────────────────────────────────────────────────────"
SSHCFG="$HOME/.ssh/config"
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
touch "$SSHCFG"; chmod 600 "$SSHCFG"
# Yedek
cp -p "$SSHCFG" "$SSHCFG.bak.$(date +%Y%m%d_%H%M%S)"
# En başta IgnoreUnknown UseKeychain yoksa ekle
first_line="$(head -n1 "$SSHCFG" || true)"
if ! grep -qE '^IgnoreUnknown[[:space:]]+UseKeychain$' <<<"${first_line:-}"; then
  { echo "IgnoreUnknown UseKeychain"; cat "$SSHCFG"; } > "$SSHCFG.tmp" && mv "$SSHCFG.tmp" "$SSHCFG"
fi
chmod 600 "$SSHCFG"

# ipucu: Hangi ssh kullanılıyor?
say "SSH binary: $(command -v ssh) | Versiyon: $(ssh -V 2>&1 || true)"
if [[ "$(command -v ssh)" != "/usr/bin/ssh" ]]; then
  say "ℹ️ VS Code Remote-SSH için system ssh kullanmak istersen Settings → 'remote.SSH.path' = /usr/bin/ssh"
fi

say "──────────────────────────────────────────────────────────────"
say "[1] Colima durumu & başlatma"
say "──────────────────────────────────────────────────────────────"
if ! colima status | grep -q "Running"; then
  say "ℹ️ Colima başlatılıyor (cpu=4, mem=6GiB, disk=60GiB)…"
  colima start --cpu 4 --memory 6 --disk 60 || {
    say "⚠️ colima start başarısız. 'colima start --edit' ile kaynakları artırıp tekrar deneyin."
    colima start --edit
    exit 1
  }
else
  say "✅ Colima çalışıyor."
fi

say "──────────────────────────────────────────────────────────────"
say "[2] containerd content store onarımı (sudo yok → nerdctl prune)"
say "──────────────────────────────────────────────────────────────"
# Bazı profillerde sudo yok; güvenli ve yeterli temizlik:
colima ssh -- "nerdctl system prune -af || true"
say "✅ Content store onarım tamam."

say "──────────────────────────────────────────────────────────────"
say "[3] Python venv & pip"
say "──────────────────────────────────────────────────────────────"
PY_BIN="$(command -v python3 || true)"
if [[ -z "${PY_BIN}" ]]; then
  say "❌ python3 yok. brew install python"
  exit 1
fi
if [[ ! -d "$APP_DIR/.venv" ]]; then
  "$PY_BIN" -m venv "$APP_DIR/.venv"
fi
VENV_BIN="$APP_DIR/.venv/bin"
"$PY_BIN" -m ensurepip --upgrade || true
"$VENV_BIN/python" -m ensurepip --upgrade || true
# get-pip.py varsa, çalıştırılabilir olmasa da python ile çağır
if [[ -f "$APP_DIR/get-pip.py" ]]; then
  "$VENV_BIN/python" "$APP_DIR/get-pip.py" || true
fi
"$VENV_BIN/python" -m pip install --upgrade pip wheel setuptools || true

say "──────────────────────────────────────────────────────────────"
say "[4] .env senkronizasyonu (ETH_SENDER_ADDRESS doldur)"
say "──────────────────────────────────────────────────────────────"
if [[ ! -f "$ENV_FILE" ]]; then
  say "❌ .env bulunamadı: $ENV_FILE"
  exit 1
fi

# HOST_PORT .env içinde varsa onu baz al
HOST_PORT_ENV="$(grep -E '^HOST_PORT=' "$ENV_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
if [[ -n "${HOST_PORT_ENV:-}" ]]; then HOST_PORT="$HOST_PORT_ENV"; fi

# ETH_SENDER_ADDRESS boş ve WALLET_ADDRESS doluysa → silmeden yeni satır ekle
if grep -q '^ETH_SENDER_ADDRESS=$' "$ENV_FILE" && grep -q '^WALLET_ADDRESS=' "$ENV_FILE"; then
  WA="$(grep '^WALLET_ADDRESS=' "$ENV_FILE" | head -n1 | cut -d= -f2-)"
  if [[ -n "${WA:-}" ]]; then
    say "ℹ️ ETH_SENDER_ADDRESS boş → WALLET_ADDRESS ile dolduruluyor: $WA"
    cp -p "$ENV_FILE" "$ENV_FILE.bak.$(date +%Y%m%d_%H%M%S)"
    awk -v wa="$WA" '
      BEGIN{added=0}
      {print}
      /^ETH_SENDER_ADDRESS=$/ && added==0 {print "ETH_SENDER_ADDRESS=" wa; added=1}
    ' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
  fi
fi

say "──────────────────────────────────────────────────────────────"
say "[5] Postgres (quantumai-db) başlat/sağlık kontrolü"
say "──────────────────────────────────────────────────────────────"
if ! docker ps --format '{{.Names}}' | grep -q "^${DB_CTR}\$"; then
  docker rm -f "$DB_CTR" >/dev/null 2>&1 || true
  docker run -d --name "$DB_CTR" -e POSTGRES_PASSWORD=postgres -p "${DB_PORT_HOST}:5432" postgres:16-alpine
fi
for i in $(seq 1 20); do
  if docker logs "$DB_CTR" 2>&1 | grep -qi "database system is ready to accept connections"; then
    say "✅ DB hazır."
    break
  fi
  say "… DB bekleniyor ($i/20)"; sleep 1
done

say "──────────────────────────────────────────────────────────────"
say "[6] GLI image çek & container başlat (retry)"
say "──────────────────────────────────────────────────────────────"
pull_ok=0
for i in $(seq 1 "$RETRIES"); do
  if docker pull "$GLI_IMAGE"; then pull_ok=1; break; fi
  say "⚠️ Pull denemesi ($i/$RETRIES) hata verdi, ${SLEEP_BETWEEN}s sonra tekrar…"
  sleep "$SLEEP_BETWEEN"
  colima ssh -- "nerdctl image prune -f" || true
done
if [[ "$pull_ok" -ne 1 ]]; then
  say "❌ Image çekilemedi: $GLI_IMAGE"
  exit 1
fi

docker rm -f "$GLI_CTR" >/dev/null 2>&1 || true
docker run -d --name "$GLI_CTR" --env-file "$ENV_FILE" -p "${HOST_PORT}:5003" "$GLI_IMAGE"

say "──────────────────────────────────────────────────────────────"
say "[7] Healthcheck → http://127.0.0.1:${HOST_PORT}/"
say "──────────────────────────────────────────────────────────────"
ok=0
for i in $(seq 1 25); do
  if curl -fsS "http://127.0.0.1:${HOST_PORT}/" >/dev/null 2>&1; then ok=1; break; fi
  printf "."; sleep 1
done
echo
if [[ "$ok" -eq 1 ]]; then
  say "✅ Uygulama ayakta: http://127.0.0.1:${HOST_PORT}/"
else
  say "⚠️ Healthcheck başarısız (port ${HOST_PORT}). Son 200 log satırı:"
  docker logs --tail 200 "$GLI_CTR" || true
fi

say "──────────────────────────────────────────────────────────────"
say "[8] Notlar"
say "──────────────────────────────────────────────────────────────"
say "• JSON dosyaları komut değildir; görüntülemek için:"
say "    less \"$APP_DIR/history_2024-10-06T05_41_56.279+03_00.json\""
say "• get-pip.py yürütülebilir olmasa bile python ile çağrıldı."
say "• Docker Desktop gerekmez; Colima ile çalışıyoruz."
say "• containerd rename/no-such-file sorunu için Colima içi temizlik uygulandı."
say
say "Tamamlandı ✅"
