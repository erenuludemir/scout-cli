set -euo pipefail

IMAGE_NAME="quantumai-usdt-v2"
DEFAULT_PORT="5003"
HOST_PORT="${HOST_PORT:-${1:-$DEFAULT_PORT}}"

case "$HOST_PORT" in ''|*[!0-9]*) echo "Bad port: $HOST_PORT" >&2; exit 1;; esac

mkdir -p integrations/etherscan

cat > integrations/etherscan/etherscan_client.py <<'PY'
from __future__ import annotations
import os, requests
from typing import Any, Dict, Optional

class EtherscanError(RuntimeError):
    pass

class BaseHTTP:
    def __init__(self, base_url: str, api_key: Optional[str] = None, timeout: int = 30):
        self.base_url = base_url.rstrip("/")
        self.api_key  = api_key or os.getenv("ETHERSCAN_API_KEY", "")
        self.timeout  = timeout

    def get(self, params: Dict[str, Any]) -> Dict[str, Any]:
        if self.api_key and "apikey" not in params:
            params["apikey"] = self.api_key
        r = requests.get(self.base_url, params=params, timeout=self.timeout)
        r.raise_for_status()
        data = r.json()
        if isinstance(data, dict) and data.get("status") == "0" and data.get("message") != "No transactions found":
            raise EtherscanError(f"Etherscan error: {data.get('message')}")
        return data

class EtherscanClient(BaseHTTP):
    """
    v1 Accounts module helper for:
      - ERC20 transfers:   action=tokentx
      - ERC721 transfers:  action=tokennfttx
      - ERC1155 transfers: action=token1155tx
    Base URL is typically https://api.etherscan.io/api (or arbiscan/bscscan equivalents).
    """
    def __init__(self, base_url: Optional[str] = None, api_key: Optional[str] = None):
        super().__init__(base_url or os.getenv("ETHERSCAN_API_URL", "https://api.etherscan.io/api"), api_key)

    def erc20_transfers(self, address: str, page: int = 1, offset: int = 10, sort: str = "desc",
                        contractaddress: Optional[str] = None,
                        startblock: int = 0, endblock: int = 99999999) -> Dict[str, Any]:
        params = dict(module="account", action="tokentx",
                      address=address, page=page, offset=offset, sort=sort,
                      startblock=startblock, endblock=endblock)
        if contractaddress:
            params["contractaddress"] = contractaddress
        return self.get(params)

    def erc721_transfers(self, address: str, page: int = 1, offset: int = 10, sort: str = "desc",
                         contractaddress: Optional[str] = None,
                         startblock: int = 0, endblock: int = 99999999) -> Dict[str, Any]:
        params = dict(module="account", action="tokennfttx",
                      address=address, page=page, offset=offset, sort=sort,
                      startblock=startblock, endblock=endblock)
        if contractaddress:
            params["contractaddress"] = contractaddress
        return self.get(params)

    def erc1155_transfers(self, address: str, page: int = 1, offset: int = 10, sort: str = "desc",
                          contractaddress: Optional[str] = None,
                          startblock: int = 0, endblock: int = 99999999) -> Dict[str, Any]:
        params = dict(module="account", action="token1155tx",
                      address=address, page=page, offset=offset, sort=sort,
                      startblock=startblock, endblock=endblock)
        if contractaddress:
            params["contractaddress"] = contractaddress
        return self.get(params)

    def get_balance_wei(self, address: str) -> int:
        params = dict(module="account", action="balance", address=address, tag="latest")
        data = self.get(params)
        return int(data.get("result", "0"))
PY

cat > integrations/etherscan/etherscan_v2.py <<'PY'
from __future__ import annotations
import os, requests
from typing import Any, Dict, Optional

class EtherscanV2Error(RuntimeError):
    pass

class EtherscanV2Client:
    """
    Simple wrapper for Etherscan v2 tokens endpoints we need:
      - /api?chainid=1&module=token&action=tokenholderlist&contractaddress=...&page=&offset=
      - /api?chainid=1&module=token&action=tokenholdercount&contractaddress=...
    Base URL stays the same; v2 is indicated by "v2=1" on some stacks, but official docs use chainid + module/action.
    """
    def __init__(self, base_url: Optional[str] = None, api_key: Optional[str] = None, chain_id: Optional[int] = None, timeout: int = 30):
        self.base_url = (base_url or os.getenv("ETHERSCAN_API_URL", "https://api.etherscan.io/api")).rstrip("/")
        self.api_key  = api_key or os.getenv("ETHERSCAN_API_KEY", "")
        self.chain_id = chain_id or int(os.getenv("ETHERSCAN_CHAIN_ID", "1"))
        self.timeout  = timeout

    def _get(self, params: Dict[str, Any]) -> Dict[str, Any]:
        if self.api_key:
            params.setdefault("apikey", self.api_key)
        params.setdefault("chainid", self.chain_id)
        r = requests.get(self.base_url, params=params, timeout=self.timeout)
        r.raise_for_status()
        data = r.json()
        return data

    def tokenholder_list(self, contractaddress: str, page: int = 1, offset: int = 10) -> Dict[str, Any]:
        params = dict(module="token", action="tokenholderlist",
                      contractaddress=contractaddress, page=page, offset=offset)
        return self._get(params)

    def tokenholder_count(self, contractaddress: str) -> Dict[str, Any]:
        params = dict(module="token", action="tokenholdercount",
                      contractaddress=contractaddress)
        return self._get(params)
PY

cat > integrations/etherscan/flask_ext.py <<'PY'
from __future__ import annotations
import os
from flask import Blueprint, jsonify, request
from .etherscan_client import EtherscanClient
from .etherscan_v2 import EtherscanV2Client

bp = Blueprint("qai_etherscan", __name__)

EXPLORER_URLS = {
    "etherscan":  os.getenv("ETHERSCAN_API_URL",  "https://api.etherscan.io/api"),
    "arbiscan":   os.getenv("ARBISCAN_API_URL",   "https://api.arbiscan.io/api"),
    "optimism":   os.getenv("OPTIMISM_API_URL",   "https://api-optimistic.etherscan.io/api"),
    "bscscan":    os.getenv("BSCSCAN_API_URL",    "https://api.bscscan.com/api"),
    "snowscan":   os.getenv("SNOWSCAN_API_URL",   "https://api.snowscan.xyz/api"),
}

def _pick_v1():
    which = request.args.get("explorer","etherscan").lower()
    base  = EXPLORER_URLS.get(which, EXPLORER_URLS["etherscan"])
    return EtherscanClient(base_url=base)

def _pick_v2():
    chainid = request.args.get("chainid", type=int) or None
    base    = request.args.get("base") or os.getenv("ETHERSCAN_API_URL", "https://api.etherscan.io/api")
    return EtherscanV2Client(base_url=base, chain_id=chainid)

@bp.get("/etherscan/erc20-transfers")
def erc20_transfers():
    q = request.args
    cli = _pick_v1()
    data = cli.erc20_transfers(
        address=q["address"],
        page=q.get("page", type=int) or 1,
        offset=q.get("offset", type=int) or 10,
        sort=q.get("sort", default="desc"),
        contractaddress=q.get("contractaddress"),
        startblock=q.get("startblock", type=int) or 0,
        endblock=q.get("endblock", type=int) or 99999999,
    )
    return jsonify(data)

@bp.get("/etherscan/erc721-transfers")
def erc721_transfers():
    q = request.args
    cli = _pick_v1()
    data = cli.erc721_transfers(
        address=q["address"],
        page=q.get("page", type=int) or 1,
        offset=q.get("offset", type=int) or 10,
        sort=q.get("sort", default="desc"),
        contractaddress=q.get("contractaddress"),
        startblock=q.get("startblock", type=int) or 0,
        endblock=q.get("endblock", type=int) or 99999999,
    )
    return jsonify(data)

@bp.get("/etherscan/erc1155-transfers")
def erc1155_transfers():
    q = request.args
    cli = _pick_v1()
    data = cli.erc1155_transfers(
        address=q["address"],
        page=q.get("page", type=int) or 1,
        offset=q.get("offset", type=int) or 10,
        sort=q.get("sort", default="desc"),
        contractaddress=q.get("contractaddress"),
        startblock=q.get("startblock", type=int) or 0,
        endblock=q.get("endblock", type=int) or 99999999,
    )
    return jsonify(data)

@bp.get("/etherscan/tokenholders")
def tokenholders_list():
    q = request.args
    cli = _pick_v2()
    data = cli.tokenholder_list(
        contractaddress=q["contractaddress"],
        page=q.get("page", type=int) or 1,
        offset=q.get("offset", type=int) or 10,
    )
    return jsonify(data)

@bp.get("/etherscan/tokenholders/count")
def tokenholders_count():
    q = request.args
    cli = _pick_v2()
    data = cli.tokenholder_count(contractaddress=q["contractaddress"])
    return jsonify(data)
PY

mkdir -p app
cat > app/__init__.py <<'PY'
from __future__ import annotations
from flask import Flask
from integrations.etherscan.flask_ext import bp as etherscan_bp

def create_app() -> Flask:
    app = Flask(__name__)
    app.register_blueprint(etherscan_bp)
    return app
PY

cat > wsgi.py <<'PY'
from app import create_app
app = create_app()
PY

cat > run.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
IMAGE_NAME="quantumai-usdt-v2"
HOST_PORT="${1:-5003}"
case "$HOST_PORT" in ''|*[!0-9]*) echo "Bad port: $HOST_PORT" >&2; exit 1;; esac

docker build -t "$IMAGE_NAME" .
docker ps --filter "ancestor=$IMAGE_NAME" -q | xargs -r docker stop
docker run --rm -p "${HOST_PORT}:8080" --env-file "$HOME/QuantumAI-Dockerized-System/.env" "$IMAGE_NAME"
SH
chmod +x run.sh

docker build -t "$IMAGE_NAME" .
docker ps --filter "ancestor=$IMAGE_NAME" -q | xargs -r docker stop || true
./run.sh "$HOST_PORT" &

echo "Waiting app on :$HOST_PORT ..."
for i in $(seq 1 60); do
  if curl -fs "http://localhost:${HOST_PORT}/" >/dev/null 2>&1; then break; fi
  sleep 1
done

ADDR="0xda93812D7D1F3D326ef8156D94175238948Da04f"
USDT="0xdAC17F958D2ee523a2206206994597C13D831ec7"
echo "ERC20 transfers status:"
curl -i "http://localhost:${HOST_PORT}/etherscan/erc20-transfers?address=${ADDR}&page=1&offset=2&sort=desc" | sed -n '1,12p'
echo "ERC721 transfers status:"
curl -i "http://localhost:${HOST_PORT}/etherscan/erc721-transfers?address=${ADDR}&page=1&offset=2" | sed -n '1,12p'
echo "ERC1155 transfers status:"
curl -i "http://localhost:${HOST_PORT}/etherscan/erc1155-transfers?address=${ADDR}&page=1&offset=2" | sed -n '1,12p'
echo "Token holder list (v2) status:"
curl -i "http://localhost:${HOST_PORT}/etherscan/tokenholders?contractaddress=${USDT}&page=1&offset=2&chainid=1" | sed -n '1,12p'
echo "Token holder count (v2) status:"
curl -i "http://localhost:${HOST_PORT}/etherscan/tokenholders/count?contractaddress=${USDT}&chainid=1" | sed -n '1,12p'

echo
echo "If Content-Type: application/json and 200 OK, you can now pipe to jq safely."
echo "Example:"
echo "curl -s \"http://localhost:${HOST_PORT}/etherscan/erc20-transfers?address=${ADDR}&page=1&offset=5&sort=desc\" | jq ."
