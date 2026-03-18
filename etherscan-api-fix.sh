#!/usr/bin/env bash
set -Eeuo pipefail; export LANG=C LC_ALL=C
ROOT="${ROOT:-$HOME/QuantumAI-Dockerized-System}"
APP_DIR="$ROOT"
ES_DIR="$ROOT/integrations/etherscan"
HEALTH_DIR="$ROOT/health"
# Export paths so that the inline Python validation step can read them via os.environ
export ES_DIR HEALTH_DIR
DEPLOY_DIR="$ROOT/.deploy"
mkdir -p "$ES_DIR" "$HEALTH_DIR"
backup() { [ -f "$1" ] && cp -a "$1" "$1.bak.$(date +%s)" || true; }
REQ="$ROOT/requirements.txt"
touch "$REQ"
grep -qiE '^[[:space:]]*Flask([[:space:]]*==|$)' "$REQ" || echo 'Flask==2.2.5' >> "$REQ"
grep -qiE '^[[:space:]]*requests([[:space:]]*==|$)' "$REQ" || echo 'requests==2.32.3' >> "$REQ"
grep -qiE '^[[:space:]]*python-dotenv([[:space:]]*==|$)' "$REQ" || echo 'python-dotenv==1.0.1' >> "$REQ"
backup "$ES_DIR/etherscan_client.py"
cat > "$ES_DIR/etherscan_client.py" <<'PY'
from __future__ import annotations
import os, typing as t, requests
JSON = t.Dict[str, t.Any]
def _env(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()
class _BaseClient:
    def __init__(self, base_url: str, api_key: str, timeout: int = 20):
        self.base_url = base_url.rstrip("/")
        self.api_key  = api_key.strip()
        if not self.api_key:
            raise RuntimeError("Missing API key for Etherscan-like client")
        self.s = requests.Session()
        self.timeout = timeout
    def _http_get(self, params: dict) -> JSON:
        p = {**params, "apikey": self.api_key}
        r = self.s.get(self.base_url, params=p, timeout=self.timeout)
        r.raise_for_status()
        data = r.json()
        if isinstance(data, dict) and str(data.get("status", "1")) == "0" and str(data.get("message", "65536")).lower().startswith("notok"):
            raise RuntimeError(f"NOTOK: {data.get('result')}")
        return data
    def _http_post(self, data: dict) -> JSON:
        d = {**data, "apikey": self.api_key}
        r = self.s.post(self.base_url, data=d, timeout=self.timeout)
        r.raise_for_status()
        return r.json()
class EtherscanClient(_BaseClient):
    """
    Classic V1 endpoints (module=?&action=? on /api). You can point this at:
      - ETHERSCAN_API_URL (Ethereum)
      - ARBISCAN_API_URL  (Arbitrum)
      - OPTIMISM_API_URL  (Optimism)
      - BSCSCAN_API_URL   (BSC)
      - SNOWSCAN_API_URL  (Avalanche)
    """
    def __init__(self, api_key: str | None = None, base_url: str | None = None, timeout: int = 20):
        api_key  = api_key or _env("ETHERSCAN_API_KEY")
        base_url = base_url or _env("ETHERSCAN_API_URL", "https://api.etherscan.io/api")
        super().__init__(base_url, api_key, timeout)
    def get_balance_wei(self, address: str) -> int:
        j = self._http_get({"module":"account","action":"balance","address":address,"tag":"latest"})
        return int(j["result"])
    def get_txlist(self, address: str, page:int=1, offset:int=100, sort:str="desc",
                   start_block:int=0, end_block:int=99999999) -> t.List[JSON]:
        j = self._http_get({"module":"account","action":"txlist","address":address,"page":page,"offset":offset,"sort":sort,
                            "startblock":start_block, "endblock":end_block})
        res = j.get("result", [])
        return res if isinstance(res, list) else []
    def erc20_transfers(self, address:str, page:int=1, offset:int=100, sort:str="desc") -> t.List[JSON]:
        j = self._http_get({"module":"account","action":"tokentx","address":address,"page":page,"offset":offset,"sort":sort})
        return j.get("result", []) or []
    def erc721_transfers(self, address:str, page:int=1, offset:int=100, sort:str="desc") -> t.List[JSON]:
        j = self._http_get({"module":"account","action":"tokennfttx","address":address,"page":page,"offset":offset,"sort":sort})
        return j.get("result", []) or []
    def erc1155_transfers(self, address:str, page:int=1, offset:int=100, sort:str="desc") -> t.List[JSON]:
        j = self._http_get({"module":"account","action":"token1155tx","address":address,"page":page,"offset":offset,"sort":sort})
        return j.get("result", []) or []
    def get_logs(self, address:str, from_block:int, to_block:int,
                 topics:dict[str,str]|None=None, topic_oprs:dict[str,str]|None=None,
                 page:int=1, offset:int=1000) -> t.List[JSON]:
        params: dict[str,t.Any] = {"module":"logs","action":"getLogs","address":address,
                                   "fromBlock":from_block,"toBlock":to_block,
                                   "page":page,"offset":offset}
        topics = topics or {}
        topic_oprs = topic_oprs or {}
        for k,v in topics.items():
            params[k] = v
        for k,v in topic_oprs.items():
            params[k] = v
        j = self._http_get(params)
        return j.get("result", []) or []
    def verify_contract(self, **fields) -> JSON:
        data = {"module":"contract","action":"verifysourcecode", **fields}
        return self._http_post(data)
class EtherscanV2Client(_BaseClient):
    """
    Etherscan V2: base_url should be .../v2/api (chain-agnostic) + chainid param on each request.
    Docs quickstart: https://docs.etherscan.io/v2-api-quickstart
    Tokens endpoints: https://docs.etherscan.io/api-endpoints/tokens (some flagged at 2 rps)
    """
    def __init__(self, chain_id:int|None = None, base_url:str|None=None, api_key:str|None=None, timeout:int=20):
        base = (base_url or _env("ETHERSCAN_API_URL","https://api.etherscan.io/api")).rstrip("/")
        if not base.endswith("/v2/api"):
            base = base.replace("/api","/v2/api")
        api_key = api_key or _env("ETHERSCAN_API_KEY")
        super().__init__(base, api_key, timeout)
        self.chain_id = chain_id or int(_env("ETHERSCAN_CHAIN_ID","1") or 1)
    def _get(self, **params) -> JSON:
        return self._http_get({"chainid": self.chain_id, **params})
    def _post(self, **data) -> JSON:
        return self._http_post({"chainid": self.chain_id, **data})
    def get_balance_wei(self, address:str) -> int:
        j = self._get(module="account", action="balance", address=address, tag="latest")
        return int(j["result"])
    def addresstokenbalance(self, address:str, page:int=1, offset:int=100) -> JSON:
        return self._get(module="tokens", action="addresstokenbalance", address=address, page=page, offset=offset)
    def addresstokennftbalance(self, address:str, page:int=1, offset:int=100) -> JSON:
        return self._get(module="tokens", action="addresstokennftbalance", address=address, page=page, offset=offset)
    def addresstokennftinventory(self, address:str, contractaddress:str, page:int=1, offset:int=100) -> JSON:
        return self._get(module="tokens", action="addresstokennftinventory",
                         address=address, contractaddress=contractaddress, page=page, offset=offset)
    def token_holder_list(self, contractaddress:str, page:int=1, offset:int=100) -> JSON:
        return self._get(module="tokens", action="tokenholderlist",
                         contractaddress=contractaddress, page=page, offset=offset)
    def token_holder_count(self, contractaddress:str) -> JSON:
        return self._get(module="tokens", action="tokenholdercount", contractaddress=contractaddress)
    def token_info(self, contractaddress:str) -> JSON:
        return self._get(module="tokens", action="tokeninfo", contractaddress=contractaddress)
    def erc20_transfers(self, address:str, page:int=1, offset:int=100, sort:str="desc") -> JSON:
        return self._get(module="account", action="tokentx", address=address, page=page, offset=offset, sort=sort)
    def erc721_transfers(self, address:str, page:int=1, offset:int=100, sort:str="desc") -> JSON:
        return self._get(module="account", action="tokennfttx", address=address, page=page, offset=offset, sort=sort)
    def erc1155_transfers(self, address:str, page:int=1, offset:int=100, sort:str="desc") -> JSON:
        return self._get(module="account", action="token1155tx", address=address, page=page, offset=offset, sort=sort)
    def get_logs(self, address:str, from_block:int, to_block:int, **kwargs) -> JSON:
        params = {"module":"logs","action":"getLogs","address":address,"fromBlock":from_block,"toBlock":to_block}
        params.update(kwargs)
        return self._get(**params)
    def verify_contract(self, **fields) -> JSON:
        data = {"module":"contract","action":"verifysourcecode", **fields}
        return self._post(**data)
PY
backup "$ES_DIR/flask_ext.py"
cat > "$ES_DIR/flask_ext.py" <<'PY'
from __future__ import annotations
import os
from flask import Blueprint, jsonify, request
from .etherscan_client import EtherscanClient, EtherscanV2Client
bp = Blueprint("qai_etherscan", __name__)
EXPLORER_URLS = {
    "etherscan": os.getenv("ETHERSCAN_API_URL", "https://api.etherscan.io/api"),
    "arbiscan":  os.getenv("ARBISCAN_API_URL",  "https://api.arbiscan.io/api"),
    "optimism":  os.getenv("OPTIMISM_API_URL",  "https://api-optimistic.etherscan.io/api"),
    "bscscan":   os.getenv("BSCSCAN_API_URL",   "https://api.bscscan.com/api"),
    "snowscan":  os.getenv("SNOWSCAN_API_URL",  "https://api.snowscan.xyz/api"),
}
API_KEYS = {
    "etherscan": os.getenv("ETHERSCAN_API_KEY", "VZFDUWB3YGQ1YCDKTCU1D6DDSS"),
    "arbiscan":  os.getenv("ARBISCAN_API_KEY",  "B6SVGA7K3YBJEQ69AFKJF4YHVX"),
    "optimism":  os.getenv("OPTIMISM_API_KEY",  "66N5FRNV1ZD4I87S7MAHCJVXFJ"),
    "bscscan":   os.getenv("BSCSCAN_API_KEY",   "ZM8ACMJB67C2IXKKBF8URFUNSY"),
    "snowscan":  os.getenv("SNOWSCAN_API_KEY",  "ATJQERBKV1CI3GVKNSE3Q7RGEJ"),
}
def _v1_client() -> EtherscanClient:
    which = request.args.get("explorer","etherscan").lower()
    base  = EXPLORER_URLS.get(which, EXPLORER_URLS["etherscan"])
    key   = API_KEYS.get(which, API_KEYS["etherscan"])
    return EtherscanClient(api_key=key, base_url=base)
def _v2_client() -> EtherscanV2Client:
    chainid = request.args.get("chainid", type=int) or None
    return EtherscanV2Client(chain_id=chainid)
@bp.get("/etherscan/balance")
def etherscan_balance():
    addr = request.args.get("address") or os.getenv("ETH_ADDRESS","0xda93812D7D1F3D326ef8156D94175238948Da04f").strip()
    if not addr:
        return jsonify(ok=False, error="address required"), 400
    if request.args.get("v2") == "1":
        cli = _v2_client()
        bal = cli.get_balance_wei(addr)
        return jsonify(ok=True, v="v2", address=addr, balance_wei=bal, balance_eth=str(bal/10**18))
    cli = _v1_client()
    bal = cli.get_balance_wei(addr)
    return jsonify(ok=True, v="v1", address=addr, balance_wei=bal, balance_eth=str(bal/10**18))
@bp.get("/etherscan/erc20-transfers")
def etherscan_erc20():
    addr   = request.args.get("address")
    page   = request.args.get("page", 1, type=int)
    offset = request.args.get("offset", 10, type=int)
    sort   = request.args.get("sort", "desc")
    if not addr:
        return jsonify(ok=False, error="address required"), 400
    if request.args.get("v2") == "1":
        data = _v2_client().erc20_transfers(addr, page=page, offset=offset, sort=sort)
        return jsonify(ok=True, v="v2", result=data)
    data = _v1_client().erc20_transfers(addr, page=page, offset=offset, sort=sort)
    return jsonify(ok=True, v="v1", result=data)
@bp.get("/etherscan/erc721-transfers")
def etherscan_erc721():
    addr   = request.args.get("address")
    page   = request.args.get("page", 1, type=int)
    offset = request.args.get("offset", 10, type=int)
    sort   = request.args.get("sort", "desc")
    if not addr:
        return jsonify(ok=False, error="address required"), 400
    if request.args.get("v2") == "1":
        data = _v2_client().erc721_transfers(addr, page=page, offset=offset, sort=sort)
        return jsonify(ok=True, v="v2", result=data)
    data = _v1_client().erc721_transfers(addr, page=page, offset=offset, sort=sort)
    return jsonify(ok=True, v="v1", result=data)
@bp.get("/etherscan/erc1155-transfers")
def etherscan_erc1155():
    addr   = request.args.get("address")
    page   = request.args.get("page", 1, type=int)
    offset = request.args.get("offset", 10, type=int)
    sort   = request.args.get("sort", "desc")
    if not addr:
        return jsonify(ok=False, error="address required"), 400
    if request.args.get("v2") == "1":
        data = _v2_client().erc1155_transfers(addr, page=page, offset=offset, sort=sort)
        return jsonify(ok=True, v="v2", result=data)
    data = _v1_client().erc1155_transfers(addr, page=page, offset=offset, sort=sort)
    return jsonify(ok=True, v="v1", result=data)
@bp.get("/etherscan/erc721-inventory")
def etherscan_erc721_inventory():
    addr = request.args.get("address")
    contract = request.args.get("contractaddress")
    page   = request.args.get("page", 1, type=int)
    offset = request.args.get("offset", 50, type=int)
    if not addr or not contract:
        return jsonify(ok=False, error="address and contractaddress required"), 400
    data = _v2_client().addresstokennftinventory(addr, contract, page=page, offset=offset)
    return jsonify(ok=True, v="v2", result=data)
@bp.get("/etherscan/erc721-holdings")
def etherscan_erc721_holdings():
    addr = request.args.get("address")
    page   = request.args.get("page", 1, type=int)
    offset = request.args.get("offset", 50, type=int)
    if not addr:
        return jsonify(ok=False, error="address required"), 400
    data = _v2_client().addresstokennftbalance(addr, page=page, offset=offset)
    return jsonify(ok=True, v="v2", result=data)
@bp.get("/etherscan/addresstokenbalance")
def etherscan_addr_token_balance():
    addr = request.args.get("address")
    page   = request.args.get("page", 1, type=int)
    offset = request.args.get("offset", 100, type=int)
    if not addr:
        return jsonify(ok=False, error="address required"), 400
    data = _v2_client().addresstokenbalance(addr, page=page, offset=offset)
    return jsonify(ok=True, v="v2", result=data)
@bp.get("/etherscan/tokenholders")
def etherscan_tokenholders():
    contract = request.args.get("contractaddress")
    page   = request.args.get("page", 1, type=int)
    offset = request.args.get("offset", 100, type=int)
    if not contract:
        return jsonify(ok=False, error="contractaddress required"), 400
    data = _v2_client().token_holder_list(contract, page=page, offset=offset)
    return jsonify(ok=True, v="v2", result=data)
@bp.get("/etherscan/tokenholders/count")
def etherscan_tokenholders_count():
    contract = request.args.get("contractaddress")
    if not contract:
        return jsonify(ok=False, error="contractaddress required"), 400
    data = _v2_client().token_holder_count(contract)
    return jsonify(ok=True, v="v2", result=data)
@bp.get("/etherscan/tokeninfo")
def etherscan_tokeninfo():
    contract = request.args.get("contractaddress")
    if not contract:
        return jsonify(ok=False, error="contractaddress required"), 400
    data = _v2_client().token_info(contract)
    return jsonify(ok=True, v="v2", result=data)
@bp.post("/etherscan/verify")
def etherscan_verify():
    use_v2 = request.args.get("v2") == "1"
    fields = request.get_json(silent=True) or request.form.to_dict()
    if use_v2:
        res = _v2_client().verify_contract(**fields)
    else:
        res = _v1_client().verify_contract(**fields)
    return jsonify(ok=True, v=("v2" if use_v2 else "v1"), result=res)
PY
backup "$HEALTH_DIR/blueprint.py"
cat > "$HEALTH_DIR/blueprint.py" <<'PY'
from __future__ import annotations
from flask import Blueprint, jsonify
bp_health = Blueprint("health", __name__)
@bp_health.get("/healthz")
def healthz():
    return jsonify(ok=True), 200
PY
backup "$APP_DIR/app.py"
cat > "$APP_DIR/app.py" <<'PY'
from __future__ import annotations
from flask import Flask, jsonify
def create_app():
    app = Flask(__name__)
    @app.get("/")
    def root():
        return jsonify(ok=True, service="quantumai-usdt-v2"), 200
    try:
        from health.blueprint import bp_health
        if not any(bp.name == bp_health.name for bp in app.blueprints.values()):
            app.register_blueprint(bp_health)
    except Exception as e:
        app.logger.warning(f"[health] blueprint register skipped: {e}")
    try:
        from integrations.etherscan.flask_ext import bp as etherscan_bp
        if not any(bp.name == etherscan_bp.name for bp in app.blueprints.values()):
            app.register_blueprint(etherscan_bp)
    except Exception as e:
        app.logger.warning(f"[qai-etherscan] blueprint register skipped: {e}")
    return app
if __name__ == "__main__":
    app = create_app()
    app.run(host="0.0.0.0", port=5002, debug=True)
PY
backup "$APP_DIR/wsgi.py"
cat > "$APP_DIR/wsgi.py" <<'PY'
from __future__ import annotations
from app import create_app
app = create_app()
PY
backup "$ROOT/run.sh"
cat > "$ROOT/run.sh" <<'SH'
#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="${ROOT:-$HOME/QuantumAI-Dockerized-System}"
IMG="${IMG:-quantumai-usdt-v2}"
HOST_PORT="${1:-5003}"
if [[ -z "${HOST_PORT}" || ! "${HOST_PORT}" =~ ^[0-9]+$ ]]; then
  echo "Bad port: ${HOST_PORT}" >&2; exit 1
fi
docker ps --filter "ancestor=${IMG}" -q | xargs -r docker stop
docker run -d --rm \
  --name "qai-usdt-${HOST_PORT}" \
  -p "${HOST_PORT}:8080" \
  --env-file "${ROOT}/.env" \
  "${IMG}"
echo "[OK] Started ${IMG} on http://localhost:${HOST_PORT}/"
SH
chmod +x "$ROOT/run.sh"
if [ -f "$DEPLOY_DIR/supervisord.conf" ]; then
    backup "$DEPLOY_DIR/supervisord.conf"
    # Force-rewrite any existing gunicorn command line to a known good value (avoids cumulative corruption)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' -E 's#^command=/usr/local/bin/gunicorn.*#command=/usr/local/bin/gunicorn -w 4 -k gthread --threads 8 --timeout 120 --bind 127.0.0.1:8000 wsgi:app#' "$DEPLOY_DIR/supervisord.conf" || true
    else
        sed -i -E 's#^command=/usr/local/bin/gunicorn.*#command=/usr/local/bin/gunicorn -w 4 -k gthread --threads 8 --timeout 120 --bind 127.0.0.1:8000 wsgi:app#' "$DEPLOY_DIR/supervisord.conf" || true
    fi
    if ! grep -q "wsgi:app" "$DEPLOY_DIR/supervisord.conf"; then
        echo "[warn] Could not confirm wsgi:app in supervisord.conf" >&2
    fi
fi
python3 - <<'PY'
import py_compile, sys
try:
    import os
    py_compile.compile(os.path.join(os.environ["ES_DIR"], "flask_ext.py"), doraise=True)
    print("[OK] flask_ext.py compiles")
except Exception as e:
    print("[ERR] flask_ext.py does not compile:", e); sys.exit(1)
PY
echo "[i] Patch files written. Now rebuild & run container..."
cd "$ROOT"
docker build -t quantumai-usdt-v2 .
docker ps --filter "ancestor=quantumai-usdt-v2" -q | xargs -r docker stop || true
"$ROOT/run.sh" 5003
sleep 2
echo "[i] Health:"
curl -s -i "http://localhost:5003/"        | sed -n '1,2p'
curl -s -i "http://localhost:5003/healthz" | sed -n '1,2p'
echo "[i] Example calls (these require valid API key & address):"
ADDR="${ETH_ADDRESS:-0xda93812D7D1F3D326ef8156D94175238948Da04f}"
echo " - ERC20 transfers (V1, default):"
curl -s "http://localhost:5003/etherscan/erc20-transfers?address=${ADDR}&page=1&offset=5&sort=desc" | head -c 200; echo
echo " - ERC20 transfers (V2, add v2=1):"
curl -s "http://localhost:5003/etherscan/erc20-transfers?v2=1&address=${ADDR}&page=1&offset=5&sort=desc" | head -c 200; echo
echo " - ERC721 transfers (V1, default):"
curl -s "http://localhost:5003/etherscan/erc721-transfers?address=${ADDR}&page=1&offset=5" | head -c 200; echo
echo " - ERC721 transfers (V2, add v2=1):"
curl -s "http://localhost:5003/etherscan/erc721-transfers?v2=1&address=${ADDR}&page=1&offset=5" | head -c 200; echo
echo " - ERC1155 transfers (V1, default):"
curl -s "http://localhost:5003/etherscan/erc1155-transfers?address=${ADDR}&page=1&offset=5" | head -c 200; echo
echo " - ERC1155 transfers (V2, add v2=1):"
curl -s "http://localhost:5003/etherscan/erc1155-transfers?v2=1&address=${ADDR}&page=1&offset=5" | head -c 200; echo
echo " - ERC721 inventory (V2, mainnet chainid=1; requires contractaddress):"
curl -s "http://localhost:5003/etherscan/erc721-inventory?v2=1&chainid=1&address=${ADDR}&contractaddress=0xdAC17F958D2ee523a2206206994597C13D831ec7&page=1&offset=50" | head -c 200; echo
echo " - Token holders (V2):"
curl -s "http://localhost:5003/etherscan/tokenholders?contractaddress=0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d&page=1&offset=10" | head -c 200; echo
echo " - Token holder count (V2):"
curl -s "http://localhost:5003/etherscan/tokenholders/count?contractaddress=0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d" | head -c 200; echo
echo "# To use V2 endpoints for supported routes, add '?v2=1' to the query string."
curl -s "http://localhost:5003/etherscan/tokenholders/count?contractaddress=0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d" | head -c 200; echo
echo "[DONE] If any curl shows HTML/404, the blueprint still isn't mounted; check container logs and ensure the Flask app is running and listening on the expected port."