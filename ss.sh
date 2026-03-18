#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"
ENV_FILE="${ENV_FILE:-$APP_DIR/.env}"
GLI_IMAGE_DEFAULT="erenuludemir/gli-app:latest"
GLI_IMAGE="${GLI_IMAGE:-$GLI_IMAGE_DEFAULT}"
GLI_CTR="gli-container"
DB_CTR="quantumai-db"
DB_PORT="${DB_PORT:-5435}"
HOST_PORT="${HOST_PORT:-5003}"
AMOUNT_DEFAULT="${AMOUNT_DEFAULT:-100000}"
LOG_DIR="${LOG_DIR:-$APP_DIR/logs}"
TMP_DIR="${TMP_DIR:-/tmp/quantumai}"
REBUILD=0
MODE=""
RECIP_OVERRIDE=""
PORT_OVERRIDE=""
ENV_OVERRIDE=""

mkdir -p "$LOG_DIR" "$TMP_DIR"

log() { printf "\033[1;96m[master]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;93m[warn]\033[0m %s\n" "$*"; }
err() { printf "\033[1;91m[err]\033[0m %s\n" "$*"; }
ts()  { date +"%Y-%m-%d_%H-%M-%S"; }

need() {
  command -v "$1" >/dev/null 2>&1 || { err "'$1' bulunamadı"; exit 1; }
}

json_get() {
  python3 - "$1" "$2" <<'PY'
import json,sys
k,f=sys.argv[1],sys.argv[2]
try:
  d=json.load(open(f))
  v=d
  for part in k.split("."):
    v=v.get(part,{})
  if isinstance(v,dict): print("")
  else: print(v)
except Exception: print("")
PY
}

wait_http_ok() {
  local url="$1" to="${2:-30}" i=0
  while (( i < to )); do
    if curl -sS "$url" >/dev/null 2>&1; then return 0; fi
    sleep 1; ((i++))
  done
  return 1
}

wait_port() {
  local h="$1" p="$2" to="${3:-30}" i=0
  while (( i < to )); do
    (echo >/dev/tcp/$h/$p) >/dev/null 2>&1 && return 0 || true
    sleep 1; ((i++))
  done
  return 1
}

usage() {
  cat <<USG
Usage:
  bash $(basename "$0") --dry-run|--live [--rebuild] [--env=<path>] [--port=<5003>] [--recipient=<0x..>] [--amount=<int>] [--image=<img>]

Flags:
  --dry-run              : GLI_DRY_RUN=1 (yayın yok, ham tx/keccak döner)
  --live                 : GLI_DRY_RUN=0 (mainnet'e yayın)
  --rebuild              : GLI imajını mevcut Dockerfile'dan yeniden derle
  --env=PATH             : .env yolu (default: $ENV_FILE)
  --port=NUM             : Host port (default: $HOST_PORT)
  --recipient=0x..       : Alıcı override (ENV'dekini ezer)
  --amount=INT           : USDT (6 ondalık *units*), varsayılan $AMOUNT_DEFAULT
  --image=NAME:TAG       : GLI image override (default: $GLI_IMAGE_DEFAULT)

Örnek:
  bash $(basename "$0") --dry-run
  bash $(basename "$0") --live --port=5007 --env="$HOME/QuantumAI-Dockerized-System/.env"
USG
}

for a in "$@"; do
  case "$a" in
    --dry-run) MODE="dry"; shift;;
    --live)    MODE="live"; shift;;
    --rebuild) REBUILD=1; shift;;
    --env=*)   ENV_OVERRIDE="${a#*=}"; shift;;
    --port=*)  PORT_OVERRIDE="${a#*=}"; shift;;
    --recipient=*) RECIP_OVERRIDE="${a#*=}"; shift;;
    --amount=*) AMOUNT_DEFAULT="${a#*=}"; shift;;
    --image=*)  GLI_IMAGE="${a#*=}"; shift;;
    -h|--help) usage; exit 0;;
    *) ;;
  esac
done

[[ -n "${ENV_OVERRIDE}" ]] && ENV_FILE="$ENV_OVERRIDE"
[[ -n "${PORT_OVERRIDE}" ]] && HOST_PORT="$PORT_OVERRIDE"

if [[ "$MODE" != "dry" && "$MODE" != "live" ]]; then
  usage; exit 1
fi

need docker
need curl
need jq
need python3

if [[ ! -f "$ENV_FILE" ]]; then
  err ".env bulunamadı: $ENV_FILE"
  exit 1
fi

log "✅ .env bulundu: $ENV_FILE"
set -a; source "$ENV_FILE"; set +a

REQ_OK=1
for v in INFURA_PROJECT_ID ETH_SENDER_ADDRESS ETH_PRIVATE_KEY; do
  if [[ -z "${!v:-}" ]]; then warn "$v boş."; REQ_OK=0; fi
done
[[ $REQ_OK -eq 0 ]] && warn "Bazı değişkenler boş, DRY-RUN çalışır; LIVE için hepsi gerekli."

RECIPIENT="$ETH_RECIPIENT_ADDRESS"
[[ -n "$RECIP_OVERRIDE" ]] && RECIPIENT="$RECIP_OVERRIDE"
[[ -z "${RECIPIENT:-}" ]] && RECIPIENT="0xRecipient"

heal_docker() {
  if ! docker ps >/dev/null 2>&1; then
    warn "Docker erişilemiyor; Colima başlatılıyor..."
    if command -v colima >/dev/null 2>&1; then
      colima start --cpu 4 --memory 8 --disk 100 || true
    fi
  fi

  if docker buildx du >/dev/null 2>&1; then
    docker buildx prune -af || true
  else
    warn "buildx du başarısız; muhtemel BuildKit DB bozulması, onarılıyor..."
    if command -v colima >/dev/null 2>&1; then
      colima stop || true
      rm -rf ~/.colima/default/docker/var/lib/docker/buildkit || true
      colima start --cpu 4 --memory 8 --disk 100
    fi
  fi
}
heal_docker

start_db() {
  log "➜ PostgreSQL başlatılıyor (container: $DB_CTR, port: $DB_PORT)…"
  docker rm -f "$DB_CTR" >/dev/null 2>&1 || true
  docker run -d --name "$DB_CTR" \
    -e POSTGRES_PASSWORD=quantumai \
    -e POSTGRES_USER=quantumai \
    -e POSTGRES_DB=quantumai \
    -p ${DB_PORT}:5432 \
    -v quantumai-db-data:/var/lib/postgresql/data \
    --health-cmd="pg_isready -U postgres || exit 1" \
    --health-interval=10s --health-retries=10 --health-timeout=5s \
    postgres:15-alpine >/dev/null

  if wait_port 127.0.0.1 "$DB_PORT" 30; then
    log "✅ PostgreSQL hazır: 127.0.0.1:$DB_PORT"
  else
    warn "PostgreSQL sağlıksız görünüyor; logs:"
    docker logs "$DB_CTR" --tail=100 || true
  fi
}

build_or_pull_gli() {
  if [[ $REBUILD -eq 1 && -f "$APP_DIR/Dockerfile" ]]; then
    log "🔨 GLI imajı yeniden derleniyor (no-cache)…"
    (cd "$APP_DIR" && docker build --no-cache -t "$GLI_IMAGE" .)
  else
    log "📦 GLI imajı kullanılacak: $GLI_IMAGE"
  fi
}

run_gli() {
  local dry_env="1"
  [[ "$MODE" == "live" ]] && dry_env="0"

  docker rm -f "$GLI_CTR" >/dev/null 2>&1 || true
  docker run -d --name "$GLI_CTR" \
    --env-file "$ENV_FILE" \
    -e GLI_DRY_RUN="$dry_env" \
    -p ${HOST_PORT}:5002 \
    "$GLI_IMAGE" >/dev/null

  local health="http://127.0.0.1:${HOST_PORT}/"
  log "Health => $health"
  if wait_http_ok "$health" 30; then
    curl -s "$health" | jq .
  else
    warn "GLI health endpoint yanıt vermedi; logs:"
    docker logs "$GLI_CTR" --tail=150 || true
  fi
}

transfer_call() {
  local amount="${1:-$AMOUNT_DEFAULT}"
  local tsfile="$LOG_DIR/transfer_$(ts).json"

  log "➜ Transfer isteği (MODE=${MODE^^}, recipient=$RECIPIENT, amount=$amount)…"
  curl -s -X POST "http://127.0.0.1:${HOST_PORT}/transfer" \
    -H 'Content-Type: application/json' \
    -d '{"recipient":"'"$RECIPIENT"'","amount":'"$amount"'}' \
    | tee "$tsfile" | jq .

  echo "$tsfile"
}

etherscan_enrich() {
  local txhash="$1"
  local out_json="$2"
  local apikey="${ETHERSCAN_API_KEY:-}"

  if [[ -z "$apikey" ]]; then
    warn "ETHERSCAN_API_KEY .env’de yok; zincir üstü detay zenginleştirme atlandı."
    return 0
  fi

  log "🔎 Etherscan proxy ile zenginleştiriliyor…"

  local tx="$(curl -s "https://api.etherscan.io/v2/api?chainid=1&module=proxy&action=eth_getTransactionByHash&txhash=$txhash&apikey=$apikey")"
  local rcpt="$(curl -s "https://api.etherscan.io/v2/api?chainid=1&module=proxy&action=eth_getTransactionReceipt&txhash=$txhash&apikey=$apikey")"
  local gasp="$(curl -s "https://api.etherscan.io/v2/api?chainid=1&module=proxy&action=eth_gasPrice&apikey=$apikey")"

  python3 - "$out_json" <<'PY'
import json,sys,os
f=sys.argv[1]
base=json.load(open(f))

def fetch(envname):
  v=os.environ.get(envname,'{}')
  try:
    return json.loads(v)
  except:
    return {"error":"parse"}

tx = fetch('EN_TX')
rc = fetch('EN_RCPT')
gp = fetch('EN_GASP')

enrich={
  "enriched": {
    "etherscan": {
      "transaction": tx,
      "receipt": rc,
      "gas_price_now": gp
    }
  }
}

base.update(enrich)
open(f,"w").write(json.dumps(base,indent=2))
PY
}

calc_fees_append() {
  local out_json="$1"
  python3 - "$out_json" <<'PY'
import json,sys,decimal
D=decimal.Decimal
f=sys.argv[1]
try:
  data=json.load(open(f))
except:
  sys.exit(0)

def hx(x): 
  try: 
    return int(x,16)
  except: 
    return None

rc = data.get("enriched",{}).get("etherscan",{}).get("receipt",{}).get("result",{})
tx = data.get("enriched",{}).get("etherscan",{}).get("transaction",{}).get("result",{})

gas_used = hx(rc.get("gasUsed","0x0"))
eff_gp   = hx(rc.get("effectiveGasPrice", tx.get("gasPrice","0x0")))
fee_wei  = (gas_used or 0) * (eff_gp or 0)
fee_eth  = D(fee_wei) / D(10**18)

status   = rc.get("status")
block    = rc.get("blockNumber")
from_a   = tx.get("from")
to_a     = tx.get("to")
input_d  = tx.get("input","0x")
tx_type  = tx.get("type")

extra = {
  "computed": {
    "transaction_fee_wei": str(fee_wei),
    "transaction_fee_eth": format(fee_eth, 'f'),
    "status_hex": status,
    "blockNumber_hex": block,
    "from": from_a, "to": to_a,
    "type": tx_type,
    "input": input_d
  }
}

data.update(extra)
open(f,"w").write(json.dumps(data,indent=2))
PY
}

start_db
build_or_pull_gli
run_gli

OUT_FILE="$(transfer_call "$AMOUNT_DEFAULT")"

TX_HASH="$(jq -r '.transaction_hash // .tx_hash_computed // empty' "$OUT_FILE" || true)"

if [[ -n "$TX_HASH" ]]; then
  export EN_TX="$(curl -s "https://api.etherscan.io/v2/api?chainid=1&module=proxy&action=eth_getTransactionByHash&txhash=$TX_HASH&apikey=${ETHERSCAN_API_KEY:-}")"
  export EN_RCPT="$(curl -s "https://api.etherscan.io/v2/api?chainid=1&module=proxy&action=eth_getTransactionReceipt&txhash=$TX_HASH&apikey=${ETHERSCAN_API_KEY:-}")"
  export EN_GASP="$(curl -s "https://api.etherscan.io/v2/api?chainid=1&module=proxy&action=eth_gasPrice&apikey=${ETHERSCAN_API_KEY:-}")"

  etherscan_enrich "$TX_HASH" "$OUT_FILE"
  calc_fees_append "$OUT_FILE"
else
  warn "Tx hash bulunamadı (DRY-RUN olabilir). Zenginleştirme atlandı."
fi

log "📄 Rapor: $OUT_FILE"
log "✔ Bitti."
