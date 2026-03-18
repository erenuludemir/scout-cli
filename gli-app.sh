#!/usr/bin/env bash
set -euo pipefail

# Root path parameterization (avoids hard‑coded absolute path after migration)
# Prefer APP_ROOT if provided; fallback to existing ROOT; final fallback = script directory's parent.
APP_ROOT="${APP_ROOT:-${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}}"
ROOT="$APP_ROOT"  # maintain backward compatibility for scripts referencing ROOT
APP_DIR="${APP_DIR:-$ROOT/gli-app}"
ENVFILE="${ENVFILE:-$ROOT/.env}"
IMAGE="${IMAGE:-erenuludemir/gli-app:latest}"
CONTAINER="${CONTAINER:-gli-container}"
DEFAULT_PORT=5002

die() { echo "❌ $*" >&2; exit 1; }
info(){ echo "➜ $*"; }

mask() {
  local s="${1:-}"; [ -z "$s" ] && { echo ""; return; }
  local n=${#s}
  if (( n <= 8 )); then echo "***"; else echo "${s:0:6}***${s: -4}"; fi
}

[ -f "$ENVFILE" ] || die ".env bulunamadı: $ENVFILE"

set -a
. "$ENVFILE"
set +a

REQUIRED=(
  INFURA_PROJECT_ID
  ETH_SENDER_ADDRESS
  ETH_PRIVATE_KEY
  ETH_RECIPIENT_ADDRESS
)

MISSING=0
for k in "${REQUIRED[@]}"; do
  v="${!k-}"
  if [ -z "${v:-}" ]; then
    echo "❌ .env eksik: $k"
    ((MISSING++))
  fi
done
(( MISSING == 0 )) || exit 1

echo "✅ .env OK"
echo "   INFURA_PROJECT_ID=$(mask "$INFURA_PROJECT_ID")"
echo "   ETH_SENDER_ADDRESS=$ETH_SENDER_ADDRESS"
echo "   ETH_PRIVATE_KEY=$(mask "$ETH_PRIVATE_KEY")"
echo "   ETH_RECIPIENT_ADDRESS=$ETH_RECIPIENT_ADDRESS"

mkdir -p "$APP_DIR"

if [ ! -f "$APP_DIR/.dockerignore" ]; then
  cat > "$APP_DIR/.dockerignore" <<'IGN'
.git
__pycache__/
*.pyc
*.log
*.tmp
.env
node_modules/
tests/
snapshots/
blobs/
refs/
IGN
fi

if [ ! -f "$APP_DIR/app.py" ]; then
  cat > "$APP_DIR/app.py" <<'PY'
from flask import Flask, request, jsonify
from web3 import Web3
from dotenv import load_dotenv
import os

load_dotenv()
app = Flask(__name__)

infura_id = os.getenv("INFURA_PROJECT_ID")
if not infura_id:
    raise RuntimeError("INFURA_PROJECT_ID missing")

web3 = Web3(Web3.HTTPProvider(f"https://mainnet.infura.io/v3/{infura_id}"))
wallet = os.getenv("ETH_SENDER_ADDRESS")
priv   = os.getenv("ETH_PRIVATE_KEY")
rcpt   = os.getenv("ETH_RECIPIENT_ADDRESS", "")

USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7"
ABI  = [{"constant": False, "inputs": [{"name": "_to","type":"address"},{"name": "_value","type":"uint256"}],
         "name": "transfer","outputs": [{"name":"","type":"bool"}],"type": "function"}]
contract = web3.eth.contract(address=USDT, abi=ABI)

@app.get("/")
def root():
    return {"ok": True, "network": "ethereum-mainnet", "sender": wallet}

@app.post("/transfer")
def transfer():
    try:
        data = request.get_json(force=True) or {}
        recipient = data.get("recipient") or rcpt
        amount = int(data.get("amount", 0))
        if not recipient or amount <= 0:
            return jsonify({"status":"error","message":"recipient/amount gerekli"}), 400
        if not wallet or not priv:
            return jsonify({"status":"error","message":"sender/private_key eksik"}), 500

        nonce = web3.eth.getTransactionCount(wallet)
        amount_wei = web3.to_wei(amount, 'mwei')  # USDT 6 decimals
        tx = contract.functions.transfer(recipient, amount_wei).build_transaction({
            "chainId": 1,
            "gas": 120000,
            "gasPrice": web3.eth.gas_price,
            "nonce": nonce
        })
        signed = web3.eth.account.sign_transaction(tx, private_key=priv)
        tx_hash = web3.eth.send_raw_transaction(signed.rawTransaction)
        return jsonify({"status":"success","transaction_hash": web3.to_hex(tx_hash)})
    except Exception as e:
        return jsonify({"status":"error","message": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("GLI_PORT","5002")))
PY
fi

if [ ! -f "$APP_DIR/Dockerfile" ]; then
  cat > "$APP_DIR/Dockerfile" <<'DOCK'
FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir flask==3.0.3 web3==6.20.1 python-dotenv==1.0.1

EXPOSE 5002
CMD ["python", "app.py"]
DOCK
fi

cd "$APP_DIR"

PORT="${GLI_PORT:-$DEFAULT_PORT}"
if lsof -tiTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  PORT=$((PORT+1))
fi

info "Docker image build ediliyor: $IMAGE"
docker build -t "$IMAGE" .

info "Eski container temizleniyor (varsa): $CONTAINER"
docker rm -f "$CONTAINER" >/dev/null 2>&1 || true

info "Container başlıyor (port $PORT)"
docker run -d --name "$CONTAINER" \
  --env-file "$ENVFILE" \
  -e GLI_PORT="$PORT" \
  -p "$PORT":"$PORT" \
  "$IMAGE" >/dev/null

sleep 2
echo "▶ Sağlık:   http://127.0.0.1:$PORT/"
echo "▶ Transfer: POST http://127.0.0.1:$PORT/transfer  -d '{\"recipient\":\"$ETH_RECIPIENT_ADDRESS\",\"amount\": 100000000}'"
echo "✅ GLI Docker servisi hazır (port $PORT)"
