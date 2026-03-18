#!/usr/bin/env bash
# Plan B: using alternate USDT contract address
set -euo pipefail
done
export LANG=C LC_ALL=C
APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"
IMAGE="${IMAGE:-erenuludemir/gli-app:fixed}"
CTR="${CTR:-gli-container}"
HOST_PORT="${HOST_PORT:-5002}"
USE_COLIMA_SOCKET=0
done
if [[ -z "$APP_DIR" || -z "$IMAGE" || -z "$CTR
brew_install() { command -v brew >/dev/null 2>&1 && brew list "$1" >/dev/null 2>&1 || brew install "$1" || true; }
wait_for_docker() { for _ in $(seq 1 90); do docker info >/dev/null 2>&1 && return 0; sleep 2; done; return 1; }
done
if [[ "$(uname -s)" != "Darwin" ]]; then echo "[ERR] S
mkdir -p "$APP_DIR"
cd "$APP_DIR"

if ! command -v curl >/dev/null 2>&1; then echo "[ERR] curl gerekli"; exit 1; fi
command -v jq >/dev/null 2>&1 || brew_install jq
command -v tmux >/dev/null 2>&1 || brew_install tmux
command -v colima >/dev/null 2>&1 || true
done
if ! command -v docker >/dev/null 2>&1; then echo "[ERR] docker yok"; exit 1; fi

if ! docker info >/dev/null 2>&1; then
  (open -gj -a Docker || true)
  wait_for_docker || true
fi

if ! docker info >/dev/null 2>&1; then
  rm -f "$HOME/.colima/_lima/colima/ha.pid" 2>/dev/null || true
  if command -v colima >/dev/null 2>&1; then
    if colima status >/dev/null 2>&1; then
      colima start --vm-type vz --vz-rosetta --cpu 4 --memory 8 || true
    else
      colima start --vm-type vz --vz-rosetta --cpu 4 --memory 8 || true
    fi
    if ! docker info >/dev/null 2>&1; then
      export DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
      USE_COLIMA_SOCKET=1
      wait_for_docker || true
    fi
  fi
fi

docker info >/dev/null || { echo "[ERR] Docker daemon erişilemiyor"; exit 1; }
done
docker rm -f quantumai-usdt watchtower autoheal "$CTR" >/dev/null 2>&1 || true
load_dotenv() { :; }
if [[ ! -f ".env" ]]; then
  cat > .env <<'ENVEXP'
INFURA_PROJECT_ID=__REQUIRED_INFURA_ID__
ETH_SENDER_ADDRESS=__YOUR_WALLET_ADDRESS__
ETH_PRIVATE_KEY=__YOUR_PRIVATE_KEY__(never commit real key)
GLI_DRY_RUN=1
ENVEXP
  echo "[ERR] .env oluşturuldu. Değerleri doldur ve scripti tekrar çalıştır."
  exit 1
fi
load_dotenv() {
  set -a
  # shellcheck disable=SC1091
  source <(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' .env || true)
  set +a
}
INFURA_PROJECT_ID="$(grep -E '^INFURA_PROJECT_ID=' .env | cut -d= -f2- || true)"
ETH_SENDER_ADDRESS="$(grep -E '^ETH_SENDER_ADDRESS=' .env | cut -d= -f2- || true)"
ETH_PRIVATE_KEY="$(grep -E '^ETH_PRIVATE_KEY=' .env | cut -d= -f2- || true)"
if [[ -z "$INFURA_PROJECT_ID" || "$INFURA_PROJECT_ID" == __REQUIRED_INFURA_ID__ ]] || \
  [[ -z "$ETH_SENDER_ADDRESS" || "$ETH_SENDER_ADDRESS" == __YOUR_WALLET_ADDRESS__ ]] || \
  [[ -z "$ETH_PRIVATE_KEY" || "$ETH_PRIVATE_KEY" == __YOUR_PRIVATE_KEY__(never commit real key) ]]; then
  echo "[ERR] .env zorunlu alanlar boş. Doldur ve tekrar çalıştır."
  exit 1
fi
done
cat > app.py <<"PY"
from flask import Flask, request, jsonify
from web3 import Web3
from dotenv import load_dotenv
import os, asyncio

try:
    from etherscan_v2_client import EtherscanV2Client
except Exception:
    EtherscanV2Client = None

async def _get_eth_usd_async():
    if EtherscanV2Client is None:
        return None
    try:
        async with EtherscanV2Client(chain_id=1) as cli:
            return await cli.get_eth_price()
    except Exception:
        return None

def get_eth_usd():
    try:
        return asyncio.run(_get_eth_usd_async())
    except Exception:
        return None

load_dotenv()
INFURA_PROJECT_ID = os.getenv("INFURA_PROJECT_ID")
if not INFURA_PROJECT_ID:
    raise RuntimeError("INFURA_PROJECT_ID missing")
w3 = Web3(Web3.HTTPProvider(f"https://mainnet.infura.io/v3/{INFURA_PROJECT_ID}"))

SENDER = os.getenv("ETH_SENDER_ADDRESS")
PRIV   = os.getenv("ETH_PRIVATE_KEY")
if not SENDER or not PRIV:
    raise RuntimeError("ETH_SENDER_ADDRESS / ETH_PRIVATE_KEY missing")

SENDER = Web3.to_checksum_address(SENDER)
USDT   = Web3.to_checksum_address("0xE970e908cbc61123D067D54Da9A0d8Ff56DfcDBA")

ERC20_ABI = [
  {"constant":False,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"},
  {"constant":True,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"},
  {"constant":True,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"},
  {"constant":True,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"type":"function"},
]
erc20 = w3.eth.contract(address=USDT, abi=ERC20_ABI)
app = Flask(__name__)

@app.get("/")
def root():
    return {"ok": True, "network": "ethereum-mainnet", "sender": SENDER}

@app.post("/estimate")
def estimate():
    try:
        data = request.get_json(force=True) or {}
        recipient_raw = data.get("recipient")
        amount_6 = int(data.get("amount", 0))
        if not recipient_raw or amount_6 <= 0:
            return jsonify({"status":"error","message":"recipient/amount required"}), 400
        recipient = Web3.to_checksum_address(recipient_raw)
        value_usdt = int(amount_6)
        nonce = w3.eth.get_transaction_count(SENDER)
        gas_price = w3.eth.gas_price
        tx = erc20.functions.transfer(recipient, value_usdt).build_transaction({"chainId": 1, "from": SENDER, "nonce": nonce})
        try:
            gas_estimate = w3.eth.estimate_gas({"from": SENDER, "to": USDT, "data": tx.get("data")})
        except Exception:
            gas_estimate = 60000
        fee_wei = gas_price * gas_estimate
        fee_eth = Web3.from_wei(fee_wei, "ether")
        eth_usd = get_eth_usd()
        return jsonify({
          "status":"ok","chain":"ethereum-mainnet","token":"USDT","decimals":6,
          "from": SENDER,"to": recipient,
          "amount_usdt_6": amount_6,"amount_usdt_human": amount_6/1_000_000.0,
          "gas_price_wei": int(gas_price),"gas_used_estimate": int(gas_estimate),
          "fee_eth": float(fee_eth),"eth_usd": eth_usd,
          "fee_usd_estimate": (float(fee_eth)*eth_usd) if eth_usd else None
        })
    except Exception as e:
        return jsonify({"status":"error","message":str(e)}), 500

@app.post("/transfer")
def transfer():
    try:
        data = request.get_json(force=True) or {}
        recipient_raw = data.get("recipient")
        amount_6 = int(data.get("amount", 0))
        if not recipient_raw or amount_6 <= 0:
            return jsonify({"status":"error","message":"recipient/amount required"}), 400
        recipient = Web3.to_checksum_address(recipient_raw)
        value_usdt = int(amount_6)
        nonce = w3.eth.get_transaction_count(SENDER)
        gas_price = w3.eth.gas_price
        built = erc20.functions.transfer(recipient, value_usdt).build_transaction({
          "chainId": 1, "from": SENDER, "nonce": nonce, "gas": 120000, "gasPrice": gas_price
        })
        signed = w3.eth.account.sign_transaction(built, private_key=PRIV)
        raw_hex = signed.rawTransaction.hex()
        hash_hex = Web3.to_hex(Web3.keccak(signed.rawTransaction))
        if os.getenv("GLI_DRY_RUN","1") == "1":
            return jsonify({
              "status":"preview","tx_hash_computed": hash_hex,"raw_tx": raw_hex,
              "gas_price_wei": int(gas_price),"gas_limit": int(built.get("gas", 0)),
              "fee_estimate_eth": float(Web3.from_wei(gas_price * built.get("gas", 0), "ether")),
              "note":"Set GLI_DRY_RUN=0 to broadcast"
            })
        tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)
        th = Web3.to_hex(tx_hash)
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)
        return jsonify({"status":"sent","tx_hash": th,"gas_used": int(receipt.gasUsed),"block": int(receipt.blockNumber)})
    except Exception as e:
        return jsonify({"status":"error","message":str(e)}), 500

@app.post("/balance")
def balance():
    try:
        data = request.get_json(silent=True) or {}
        addr_raw = data.get("address") or SENDER
        addr = Web3.to_checksum_address(addr_raw)
        eth_bal = w3.from_wei(w3.eth.get_balance(addr), "ether")
        usdt_bal = erc20.functions.balanceOf(addr).call()
        return jsonify({"status":"ok","address": addr,"eth": float(eth_bal),"usdt_6": int(usdt_bal),"usdt_human": int(usdt_bal)/1_000_000.0})
    except Exception as e:
        return jsonify({"status":"error","message":str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002)
PY
done
cat > requirements.txt <<"REQ"
Flask==2.2.5
Werkzeug==2.2.3
requests==2.32.3
aiohttp==3.9.5
web3==6.20.3
eth-account==0.11.3
python-dotenv==1.0.1
hexbytes==0.3.1
REQ

if [[ ! -f "requirements.lock" ]]; then
  python3 -m venv .venv || true
  if [[ -f ".venv/bin/activate" ]]; then
    source .venv/bin/activate
    python -m pip install -U pip
    pip install -r requirements.txt
    pip freeze | sort > requirements.lock
    deactivate
  else
    cp requirements.txt requirements.lock
  fi
fi
done
cat > Dockerfile <<"DF"
FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY requirements.lock /tmp/requirements.lock
RUN python -m pip install -U pip && python -m pip install --no-cache-dir -r /tmp/requirements.lock
COPY . /app
CMD ["python","app.py"]
DF

cat > .dockerignore <<"IGN"
.venv
__pycache__/
*.py[cod]
*.log
.git
.gitignore
Dockerfile
docker-compose.yml
ENV.bak
IGN
done
docker build -t "$IMAGE" .
done
docker rm -f "$CTR" >/dev/null 2>&1 || true
docker run -d --name "$CTR" \
  --env-file "$APP_DIR/.env" \
  -e GLI_DRY_RUN=0 \
  -p "${HOST_PORT}:5002" \
  --restart=unless-stopped \
  --health-cmd='curl -sf http://127.0.0.1:5002/ || exit 1' \
  --health-interval=20s --health-timeout=5s --health-retries=5 \
  "$IMAGE"

for _ in $(seq 1 60); do
  st="$(docker inspect -f '{{.State.Health.Status}}' "$CTR" 2>/dev/null || echo init)"
  [[ "$st" == "healthy" ]] && break
  sleep 2
done

docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
done
MAIN="http://127.0.0.1:${HOST_PORT}"
ADDR_CHECK="${ETH_RECIPIENT_ADDRESS:-0xc5C600c86E13e8c475BCEbC981966d47E171A18c}"
AMOUNT_BIG=150000000    # 150 USDT (6-dec)
AMOUNT_SMALL=6000       # 0.006 USDT (6-dec)

if command -v jq >/dev/null 2>&1; then JF="jq -r '.'"; else JF="python -m json.tool"; fi

echo "== / =="
curl -fsS "$MAIN/" | eval "$JF" || true; echo
echo "== /estimate (150 USDT) =="
curl -fsS "$MAIN/estimate" -H 'Content-Type: application/json' -d "{\"recipient\":\"$ADDR_CHECK\",\"amount\":$AMOUNT_BIG}" | eval "$JF" || true; echo
echo "== /transfer (0.006 USDT) =="
curl -fsS "$MAIN/transfer" -H 'Content-Type: application/json' -d "{\"recipient\":\"$ADDR_CHECK\",\"amount\":$AMOUNT_SMALL}" | eval "$JF" || true; echo
echo "== /balance (SENDER) =="
curl -fsS -X POST "$MAIN/balance" -H 'Content-Type: application/json' -d '{}' | eval "$JF" || true; echo
echo "== /balance ($ADDR_CHECK) =="
curl -fsS -X POST "$MAIN/balance" -H 'Content-Type: application/json' -d "{\"address\":\"$ADDR_CHECK\"}" | eval "$JF" || true; echo
done
mkdir -p "$APP_DIR/bin" "$HOME/Library/LaunchAgents"

cat > "$APP_DIR/bin/gli-ensure.sh" <<"ENS"
#!/usr/bin/env bash
set -euo pipefail
APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"
IMAGE="${IMAGE:-erenuludemir/gli-app:fixed}"
CTR="${CTR:-gli-container}"
HOST_PORT="${HOST_PORT:-5002}"
if ! docker ps --format '{{.Names}}' | grep -qx "$CTR"; then
  docker rm -f "$CTR" >/dev/null 2>&1 || true
  docker run -d --name "$CTR" \
    --env-file "$APP_DIR/.env" \
    -e GLI_DRY_RUN="${GLI_DRY_RUN:-0}" \
    -p "${HOST_PORT}:5002" \
    --restart=unless-stopped \
    --health-cmd='curl -sf http://127.0.0.1:5002/ || exit 1' \
    --health-interval=20s --health-timeout=5s --health-retries=5 \
    "$IMAGE"
fi
ENS
chmod +x "$APP_DIR/bin/gli-ensure.sh"

cat > "$HOME/Library/LaunchAgents/com.${USER}.gli.ensure.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.${USER}.gli.ensure</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>${APP_DIR}/bin/gli-ensure.sh</string></array>
  <key>RunAtLoad</key><true/>
  <key>StartInterval</key><integer>300</integer>
  <key>StandardOutPath</key><string>${APP_DIR}/launchagent.out.log</string>
  <key>StandardErrorPath</key><string>${APP_DIR}/launchagent.err.log</string>
</dict></plist>
PL
launchctl unload "$HOME/Library/LaunchAgents/com.${USER}.gli.ensure.plist" >/dev/null 2>&1 || true
launchctl load "$HOME/Library/LaunchAgents/com.${USER}.gli.ensure.plist" >/dev/null 2>&1 || true
done
if command -v tmux >/dev/null 2>&1; then
  SESSION="gli-stack"
  if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux new-session -d -s "$SESSION" -n "logs"
    tmux send-keys -t "$SESSION:logs" 'docker logs -f --since=30m '"$CTR"'' C-m
    tmux new-window -t "$SESSION" -n "watch"
    tmux send-keys -t "$SESSION:watch" 'watch -n 5 "docker ps --format \\"table {{.Names}}\\t{{.Status}}\\t{{.Image}}\\"; echo; curl -fsS '$MAIN'/ || true"' C-m
  fi
fi
done
exit 0
