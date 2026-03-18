set -euo pipefail

APP_DIR="gli-app"
IMAGE="gli-app:latest"
CONTAINER="gli-container"
HOST_PORT="${HOST_PORT:-5001}"
CHAIN_ID="${CHAIN_ID:-1}"
mkdir -p "$APP_DIR"
cd "$APP_DIR"

cat > requirements.txt <<'REQ'
Flask==2.1.1
Werkzeug==2.1.2
requests==2.32.3
python-dotenv==1.0.1
gunicorn==20.1.0
REQ

if [[ ! -f .env ]]; then
  cat > .env <<'ENV'
ETHERSCAN_API_KEY=YourApiKeyToken

CHAIN_ID=1

FLASK_ENV=production
ENV
fi

mkdir -p appmod
cat > appmod/etherscan_v2_client.py <<'PY'
import os
import time
import requests
from urllib.parse import urlencode

class EtherscanV2Client:
    """
    Basit, senkron Etherscan v2 istemcisi (Accounts modülü ağırlıklı).
    Zincir seçimi için 'chainid' parametresi kullanılır (varsayılan: 1).
    """
    def __init__(self, api_key: str, chain_id: int = 1, base_url: str = "https://api.etherscan.io/v2/api", timeout=20):
        self.api_key = api_key
        self.chain_id = chain_id
        self.base_url = base_url
        self.timeout = timeout

    def _get(self, module: str, action: str, **params):
        q = {
            "chainid": self.chain_id,
            "module": module,
            "action": action,
            "apikey": self.api_key,
        }
        q.update({k: v for k, v in params.items() if v is not None})
        url = f"{self.base_url}?{urlencode(q, doseq=True)}"
        r = requests.get(url, timeout=self.timeout)
        r.raise_for_status()
        return r.json()

    def balance(self, address: str, tag: str = "latest"):
        return self._get("account", "balance", address=address, tag=tag)

    def balancemulti(self, addresses: list, tag: str = "latest"):
        return self._get("account", "balancemulti", address=",".join(addresses), tag=tag)

    def txlist(self, address: str, startblock=0, endblock=99999999, page=1, offset=10, sort="asc"):
        return self._get("account", "txlist", address=address, startblock=startblock, endblock=endblock,
                         page=page, offset=offset, sort=sort)

    def txlistinternal_by_address(self, address: str, startblock=0, endblock=99999999, page=1, offset=10, sort="asc"):
        return self._get("account", "txlistinternal", address=address, startblock=startblock,
                         endblock=endblock, page=page, offset=offset, sort=sort)

    def txlistinternal_by_txhash(self, txhash: str):
        return self._get("account", "txlistinternal", txhash=txhash)

    def txlistinternal_by_blockrange(self, startblock: int, endblock: int, page=1, offset=10, sort="asc"):
        return self._get("account", "txlistinternal", startblock=startblock, endblock=endblock,
                         page=page, offset=offset, sort=sort)

    def tokentx(self, address: str=None, contractaddress: str=None, page=1, offset=100, startblock=0, endblock=99999999, sort="asc"):
        return self._get("account", "tokentx", address=address, contractaddress=contractaddress, page=page,
                         offset=offset, startblock=startblock, endblock=endblock, sort=sort)

    def tokennfttx(self, address: str=None, contractaddress: str=None, page=1, offset=100, startblock=0, endblock=99999999, sort="asc"):
        return self._get("account", "tokennfttx", address=address, contractaddress=contractaddress, page=page,
                         offset=offset, startblock=startblock, endblock=endblock, sort=sort)

    def token1155tx(self, address: str=None, contractaddress: str=None, page=1, offset=100, startblock=0, endblock=99999999, sort="asc"):
        return self._get("account", "token1155tx", address=address, contractaddress=contractaddress, page=page,
                         offset=offset, startblock=startblock, endblock=endblock, sort=sort)

    def fundedby(self, address: str):
        return self._get("account", "fundedby", address=address)

    def getminedblocks(self, address: str, blocktype: str="blocks", page=1, offset=10):
        return self._get("account", "getminedblocks", address=address, blocktype=blocktype, page=page, offset=offset)
PY

cat > app.py <<'PY'
import os
from flask import Flask, request, jsonify
from dotenv import load_dotenv
from appmod.etherscan_v2_client import EtherscanV2Client

load_dotenv()

ETHERSCAN_API_KEY = os.getenv("ETHERSCAN_API_KEY", "YourApiKeyToken")
CHAIN_ID = int(os.getenv("CHAIN_ID", "1"))

app = Flask(__name__)
client = EtherscanV2Client(api_key=ETHERSCAN_API_KEY, chain_id=CHAIN_ID)

@app.get("/health")
def health():
    return jsonify(status="ok", chain_id=CHAIN_ID)

@app.get("/")
def index():
    return jsonify(
        message="GLI Etherscan v2 proxy",
        health="/health",
        examples={
            "balance": f"/api/balance/0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae",
            "txlist": f"/api/txlist?address=0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC&offset=2",
            "tokentx": f"/api/tokentx?address=0x4e83362442b8d1bec281594cea3050c8eb01311c&contractaddress=0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2&offset=2",
            "fundedby": f"/api/fundedby?address=0x8f5419c8797cbdecaf3f2f1910d192f4306d527d",
            "getminedblocks": f"/api/getminedblocks?address=0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b&blocktype=blocks&offset=3",
        },
        note="ETHERSCAN_API_KEY .env içinde ayarlanmalı"
    )

@app.get("/api/balance/<address>")
def api_balance(address):
    tag = request.args.get("tag", "latest")
    return jsonify(client.balance(address, tag))

@app.get("/api/balancemulti")
def api_balancemulti():
    addresses = request.args.get("address", "")
    addrs = [a.strip() for a in addresses.split(",") if a.strip()]
    if not addrs:
        return jsonify({"status":"0","message":"address param required"}), 400
    return jsonify(client.balancemulti(addrs, request.args.get("tag","latest")))

@app.get("/api/txlist")
def api_txlist():
    q = request.args
    return jsonify(client.txlist(
        q.get("address",""),
        int(q.get("startblock",0)),
        int(q.get("endblock",99999999)),
        int(q.get("page",1)),
        int(q.get("offset",10)),
        q.get("sort","asc")
    ))

@app.get("/api/txlistinternal/address")
def api_txlistinternal_addr():
    q = request.args
    return jsonify(client.txlistinternal_by_address(
        q.get("address",""),
        int(q.get("startblock",0)),
        int(q.get("endblock",99999999)),
        int(q.get("page",1)),
        int(q.get("offset",10)),
        q.get("sort","asc")
    ))

@app.get("/api/txlistinternal/tx")
def api_txlistinternal_tx():
    txhash = request.args.get("txhash","")
    return jsonify(client.txlistinternal_by_txhash(txhash))

@app.get("/api/txlistinternal/blockrange")
def api_txlistinternal_blockrange():
    q = request.args
    return jsonify(client.txlistinternal_by_blockrange(
        int(q.get("startblock",0)), int(q.get("endblock",0)),
        int(q.get("page",1)), int(q.get("offset",10)), q.get("sort","asc")
    ))

@app.get("/api/tokentx")
def api_tokentx():
    q = request.args
    return jsonify(client.tokentx(
        q.get("address"), q.get("contractaddress"),
        int(q.get("page",1)), int(q.get("offset",10)),
        int(q.get("startblock",0)), int(q.get("endblock",99999999)), q.get("sort","asc")
    ))

@app.get("/api/tokennfttx")
def api_tokennfttx():
    q = request.args
    return jsonify(client.tokennfttx(
        q.get("address"), q.get("contractaddress"),
        int(q.get("page",1)), int(q.get("offset",10)),
        int(q.get("startblock",0)), int(q.get("endblock",99999999)), q.get("sort","asc")
    ))

@app.get("/api/token1155tx")
def api_token1155tx():
    q = request.args
    return jsonify(client.token1155tx(
        q.get("address"), q.get("contractaddress"),
        int(q.get("page",1)), int(q.get("offset",10)),
        int(q.get("startblock",0)), int(q.get("endblock",99999999)), q.get("sort","asc")
    ))

@app.get("/api/fundedby")
def api_fundedby():
    address = request.args.get("address","")
    return jsonify(client.fundedby(address))

@app.get("/api/getminedblocks")
def api_getminedblocks():
    q = request.args
    return jsonify(client.getminedblocks(q.get("address",""), q.get("blocktype","blocks"),
                                        int(q.get("page",1)), int(q.get("offset",10))))

if __name__ == "__main__":
    app.run("0.0.0.0", 5000)
PY

cat > Dockerfile <<'DOCKER'
FROM python:3.9-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
EXPOSE 5000
CMD ["gunicorn","-b","0.0.0.0:5000","app:app"]
DOCKER

echo "🔨 Docker image build ediliyor..."
docker build -t "$IMAGE" .

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "🧹 Eski konteyner kaldırılıyor: ${CONTAINER}"
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
fi

echo "🚀 Konteyner başlatılıyor (host:${HOST_PORT} -> container:5000)..."
docker run -d --name "$CONTAINER" --env-file .env -p "${HOST_PORT}:5000" "$IMAGE" >/dev/null

echo -n "⏳ Health kontrolü: "
for i in $(seq 1 30); do
  if curl -fsS "http://localhost:${HOST_PORT}/health" >/dev/null; then
    echo "OK"
    break
  fi
  sleep 1
  if [[ $i -eq 30 ]]; then
    echo "BAŞARISIZ (Health endpoint'e ulaşılamadı)"
    docker logs "$CONTAINER" || true
    exit 1
  fi
done

echo "✅ Her şey hazır!"
echo "   - Health:  http://localhost:${HOST_PORT}/health"
echo "   - Ana sayfa & örnekler:  http://localhost:${HOST_PORT}/"
echo
echo "ℹ️  Etherscan çağrıları için .env içindeki ETHERSCAN_API_KEY değerini doldurmayı unutma."