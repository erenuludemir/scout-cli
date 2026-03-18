export DOCKER_USERNAME="erenuludemir"
export DOCKER_PAT="dckr_pat_DZ7yqjlEYIEXGF0Sodw30_iwPMg"

set -Eeuo pipefail

export LANG=C LC_ALL=C
APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"
SCRIPTS_DIR="$APP_DIR/scripts"
IMAGE="${IMAGE:-erenuludemir/gli-app:fixed}"
CTR="${CTR:-gli-container}"
HOST_PORT="${HOST_PORT:-5002}"
USDT_CONTRACT_ADDRESS="${USDT_CONTRACT_ADDRESS:-0xdAC17F958D2ee523a2206206994597C13D831ec7}"
mkdir -p "$APP_DIR" "$SCRIPTS_DIR"
cd "$APP_DIR"
if [[ ! -f ".env" ]]; then
  cat > .env <<'ENVEXP'
APP_DIR="$HOME/QuantumAI-Dockerized-System"
HOST_PORT=5003
PLAN=A
GLI_DRY_RUN=0
DEFAULT_CHAINID=1
INFURA_PROJECT_ID=__REQUIRED_INFURA_ID__
ETH_SENDER_ADDRESS=__YOUR_WALLET_ADDRESS__
ETH_PRIVATE_KEY=__YOUR_PRIVATE_KEY__(never commit real key)
RECEIVER_ADDRESS=__RECEIVER_WALLET_ADDRESS__
USDT_CONTRACT_ADDRESS=0xdAC17F958D2ee523a2206206994597C13D831ec7
TRANSFER_AMOUNT_6=6000
ENVEXP
  echo "[ERR] .env olusturuldu; gerekli alanlari doldurun ve komutu tekrar calistirin."
  exit 1
fi
set -a; source .env; set +a
: "${INFURA_PROJECT_ID:?[ERR] .env INFURA_PROJECT_ID yok}"
: "${ETH_SENDER_ADDRESS:?[ERR] .env ETH_SENDER_ADDRESS yok}"
: "${ETH_PRIVATE_KEY:?[ERR] .env ETH_PRIVATE_KEY yok}"
HOST_PORT="${HOST_PORT:-$HOST_PORT}"
USDT_CONTRACT_ADDRESS="${USDT_CONTRACT_ADDRESS:-$USDT_CONTRACT_ADDRESS}"
PYREQ="$APP_DIR/requirements.lock"
cat > "$PYREQ" <<'REQ'
Flask==2.2.5
Werkzeug==2.2.3
requests==2.32.3
aiohttp==3.9.5
web3==6.20.3
eth-account==0.11.3
python-dotenv==1.0.1
hexbytes==0.3.1
qrcode==7.4.2
fpdf2==2.7.9
REQ
cat > "$APP_DIR/app.py" <<PY
from flask import Flask,request,jsonify
from web3 import Web3
from dotenv import load_dotenv
import os,base64,io,qrcode,math
load_dotenv()
INFURA_PROJECT_ID=os.getenv("INFURA_PROJECT_ID","").strip()
if not INFURA_PROJECT_ID: raise RuntimeError("INFURA_PROJECT_ID missing")
w3=Web3(Web3.HTTPProvider(f"https://mainnet.infura.io/v3/{INFURA_PROJECT_ID}", request_kwargs={"timeout":30}))
if w3.eth.chain_id!=1: raise RuntimeError("Not on Ethereum mainnet")
SENDER=os.getenv("ETH_SENDER_ADDRESS",""); PRIV=os.getenv("ETH_PRIVATE_KEY","")
USDT_ADDR=os.getenv("USDT_CONTRACT_ADDRESS","$USDT_CONTRACT_ADDRESS")
if not SENDER or not PRIV: raise RuntimeError("ETH_SENDER_ADDRESS/ETH_PRIVATE_KEY missing")
SENDER=Web3.to_checksum_address(SENDER); USDT=Web3.to_checksum_address(USDT_ADDR)
ERC20_ABI=[{"constant":False,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"},{"constant":True,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"},{"constant":True,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"},{"constant":True,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"type":"function"}]
erc20=w3.eth.contract(address=USDT,abi=ERC20_ABI)
app=Flask(__name__)
def suggest_fees():
    block=w3.eth.get_block("latest")
    base=block.get("baseFeePerGas",w3.to_wei(15,"gwei"))
    try: tip=w3.eth.max_priority_fee
    except Exception: tip=None
    if not tip or (isinstance(tip,int) and tip==0): tip=w3.to_wei(1.5,"gwei")
    return int(base*2+int(tip)), int(tip)
def estimate_gas_for_transfer(to_addr:int,amount:int):
    data=erc20.functions.transfer(to_addr,amount).build_transaction({"from":SENDER}).get("data")
    try: ge=w3.eth.estimate_gas({"from":SENDER,"to":USDT,"data":data})
    except Exception: ge=60000
    return int(math.ceil(ge*1.2))
def preflight(to_addr,amount):
    to_chk=Web3.to_checksum_address(to_addr)
    ge=estimate_gas_for_transfer(to_chk,amount)
    maxfee,tip=suggest_fees()
    fee_wei=maxfee*ge
    bal_eth=w3.eth.get_balance(SENDER)
    bal_token=erc20.functions.balanceOf(SENDER).call()
    dec=erc20.functions.decimals().call()
    sym=erc20.functions.symbol().call()
    return {"to":to_chk,"amount":int(amount),"decimals":int(dec),"symbol":sym,"gas_estimate":int(ge),"maxFeePerGas":int(maxfee),"maxPriorityFeePerGas":int(tip),"fee_eth":float(Web3.from_wei(fee_wei,"ether")),"fee_wei":int(fee_wei),"eth_balance_eth":float(Web3.from_wei(bal_eth,"ether")),"token_balance_units":int(bal_token)}
@app.get("/")
def root():
    return {"ok":True,"network":"ethereum-mainnet","sender":SENDER,"usdt":USDT}
@app.post("/estimate")
def estimate():
    try:
        d=request.get_json(force=True) or {}
        r=d.get("recipient"); a=int(d.get("amount",0))
        if not r or a<=0: return jsonify({"status":"error","message":"recipient/amount required"}),400
        pf=preflight(r,a); pf["fee_usd_estimate"]=None; pf["status"]="ok"; return jsonify(pf)
    except Exception as e:
        return jsonify({"status":"error","message":str(e)}),500
@app.post("/transfer")
def transfer():
    try:
        d=request.get_json(force=True) or {}
        r=d.get("recipient"); a=int(d.get("amount",0))
        if not r or a<=0: return jsonify({"status":"error","message":"recipient/amount required"}),400
        pf=preflight(r,a)
        if os.getenv("GLI_DRY_RUN","1")=="1":
            return jsonify({"status":"preview",**pf})
        if pf["token_balance_units"]<a: return jsonify({"status":"error","message":"insufficient token balance","preflight":pf}),400
        if pf["eth_balance_eth"]<pf["fee_eth"]: return jsonify({"status":"error","message":"insufficient ETH for gas","preflight":pf}),400
        n=w3.eth.get_transaction_count(SENDER)
        maxfee,tip=pf["maxFeePerGas"],pf["maxPriorityFeePerGas"]
        built=erc20.functions.transfer(pf["to"],a).build_transaction({"chainId":1,"from":SENDER,"nonce":n,"gas":pf["gas_estimate"],"maxFeePerGas":maxfee,"maxPriorityFeePerGas":tip})
        signed=w3.eth.account.sign_transaction(built,private_key=os.getenv("ETH_PRIVATE_KEY"))
        txh=w3.eth.send_raw_transaction(signed.rawTransaction)
        th=Web3.to_hex(txh); rc=w3.eth.wait_for_transaction_receipt(txh,timeout=300)
        buf=io.BytesIO(); qrcode.make(th).save(buf,format="PNG"); b64=base64.b64encode(buf.getvalue()).decode()
        return jsonify({"status":"sent","tx_hash":th,"gas_used":int(rc.gasUsed),"block":int(rc.blockNumber),"qr_png_base64":b64})
    except Exception as e:
        return jsonify({"status":"error","message":str(e)}),500
@app.post("/balance")
def balance():
    try:
        d=request.get_json(silent=True) or {}
        addr=Web3.to_checksum_address(d.get("address") or SENDER)
        eth_bal=w3.from_wei(w3.eth.get_balance(addr),"ether")
        usdt_bal=erc20.functions.balanceOf(addr).call()
        return jsonify({"status":"ok","address":addr,"eth":float(eth_bal),"usdt_6":int(usdt_bal),"usdt_human":int(usdt_bal)/1_000_000.0})
    except Exception as e:
        return jsonify({"status":"error","message":str(e)}),500
if __name__=="__main__": app.run(host="0.0.0.0",port=int(os.getenv("HOST_PORT","$HOST_PORT")))
PY
cat > "$SCRIPTS_DIR/usdt_transfer_cli.py" <<PY
#!/usr/bin/env python3
import os,sys,json,math
from web3 import Web3
from dotenv import load_dotenv
def req(k):
    v=os.getenv(k)
    if not v:
        print(json.dumps({"status":"error","message":f"missing {k}"}),flush=True); sys.exit(1)
    return v
def suggest_fees(w3):
    block=w3.eth.get_block("latest")
    base=block.get("baseFeePerGas",w3.to_wei(15,"gwei"))
    try: tip=w3.eth.max_priority_fee
    except Exception: tip=None
    if not tip or (isinstance(tip,int) and tip==0): tip=w3.to_wei(1.5,"gwei")
    return int(base*2+int(tip)), int(tip)
def estimate_gas(w3,token,from_addr,to_addr,amount):
    data=token.functions.transfer(to_addr,amount).build_transaction({"from":from_addr}).get("data")
    try: ge=w3.eth.estimate_gas({"from":from_addr,"to":token.address,"data":data})
    except Exception: ge=60000
    return int(math.ceil(ge*1.2))
def main():
    load_dotenv()
    infura=req("INFURA_PROJECT_ID").strip()
    sender=Web3.to_checksum_address(req("ETH_SENDER_ADDRESS"))
    priv=req("ETH_PRIVATE_KEY")
    recv=Web3.to_checksum_address(os.getenv("RECEIVER_ADDRESS") or req("RECEIVER_ADDRESS"))
    amount_6=int(os.getenv("TRANSFER_AMOUNT_6","6000"))
    token_addr=Web3.to_checksum_address(os.getenv("USDT_CONTRACT_ADDRESS","$USDT_CONTRACT_ADDRESS"))
    dry=os.getenv("GLI_DRY_RUN","1")
    w3=Web3(Web3.HTTPProvider(f"https://mainnet.infura.io/v3/{infura}", request_kwargs={"timeout":30}))
    if w3.eth.chain_id!=1: print(json.dumps({"status":"error","message":"not mainnet"})); sys.exit(1)
    abi=[{"constant":False,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"},{"constant":True,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"},{"constant":True,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"}]
    token=w3.eth.contract(address=token_addr,abi=abi)
    ge=estimate_gas(w3,token,sender,recv,amount_6)
    maxfee,tip=suggest_fees(w3)
    fee_wei=maxfee*ge
    eth_bal=w3.eth.get_balance(sender)
    tok_bal=token.functions.balanceOf(sender).call()
    pre={"status":"preflight","sender":sender,"receiver":recv,"token":token_addr,"amount_6":amount_6,"gas_estimate":ge,"maxFeePerGas":maxfee,"maxPriorityFeePerGas":tip,"fee_eth":float(Web3.from_wei(fee_wei,"ether")),"eth_balance_eth":float(Web3.from_wei(eth_bal,"ether")),"token_balance_units":int(tok_bal)}
    print(json.dumps(pre,ensure_ascii=False))
    if dry=="1":
        print(json.dumps({"status":"preview","note":"GLI_DRY_RUN=0 set to broadcast"},ensure_ascii=False)); return
    if tok_bal<amount_6: print(json.dumps({"status":"error","message":"insufficient token balance"},ensure_ascii=False)); sys.exit(1)
    if eth_bal<fee_wei: print(json.dumps({"status":"error","message":"insufficient ETH for gas"},ensure_ascii=False)); sys.exit(1)
    nonce=w3.eth.get_transaction_count(sender)
    tx=token.functions.transfer(recv,amount_6).build_transaction({"chainId":1,"from":sender,"nonce":nonce,"gas":ge,"maxFeePerGas":maxfee,"maxPriorityFeePerGas":tip})
    signed=w3.eth.account.sign_transaction(tx,private_key=priv)
    txh=w3.eth.send_raw_transaction(signed.rawTransaction)
    rc=w3.eth.wait_for_transaction_receipt(txh,timeout=300)
    print(json.dumps({"status":"sent","tx_hash":w3.to_hex(txh),"block":int(rc.blockNumber),"gas_used":int(rc.gasUsed)},ensure_ascii=False))
if __name__=="__main__": main()
PY
chmod +x "$SCRIPTS_DIR/usdt_transfer_cli.py"
python3 -m venv "$APP_DIR/.venv-host" >/dev/null 2>&1 || true
source "$APP_DIR/.venv-host/bin/activate"
python -m pip install -U pip >/dev/null
pip install -r "$PYREQ" >/dev/null
deactivate
if command -v brew >/dev/null 2>&1; then
  BREW_PREFIX="$(brew --prefix)" || true
  export PATH="$BREW_PREFIX/bin:$PATH"
fi
if ! command -v colima >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then brew install colima docker >/dev/null; fi
fi
DOCKER_OK=0
if command -v colima >/dev/null 2>&1; then
  export COLIMA_HOME="${COLIMA_HOME:-$HOME/.colima}"
  export DOCKER_HOST="unix://$COLIMA_HOME/default/docker.sock"
  # If socket missing or daemon down, (re)start colima
  if [[ ! -S "$COLIMA_HOME/default/docker.sock" ]]; then
    colima start default --runtime docker --arch aarch64 --cpu 4 --memory 6 --disk 60 --network-address >/dev/null 2>&1 || colima start --runtime docker >/dev/null 2>&1 || true
  fi
  for _ in $(seq 1 30); do
    [[ -S "$COLIMA_HOME/default/docker.sock" ]] && break || sleep 1
  done
  export DOCKER_HOST="unix://$COLIMA_HOME/default/docker.sock"
  if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then DOCKER_OK=1; fi
  fi
fi
if [[ "$DOCKER_OK" -eq 1 ]]; then
  cat > Dockerfile <<DF
FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY requirements.lock /tmp/requirements.lock
RUN python -m pip install -U pip && pip install --no-cache-dir -r /tmp/requirements.lock
COPY . /app
EXPOSE $HOST_PORT
CMD ["python","app.py"]
DF
  docker rm -f "$CTR" >/dev/null 2>&1 || true
  docker build -t "$IMAGE" . >/dev/null
  docker run -d --name "$CTR" \
    --env-file "$APP_DIR/.env" \
    -e USDT_CONTRACT_ADDRESS="$USDT_CONTRACT_ADDRESS" \
    -e HOST_PORT="$HOST_PORT" \
    -p "$HOST_PORT:$HOST_PORT" \
    --restart=unless-stopped \
    --health-cmd='sh -c "curl -sf http://127.0.0.1:'"$HOST_PORT"'/ >/dev/null || exit 1"' \
    --health-interval=20s --health-timeout=5s --health-retries=5 \
    "$IMAGE" >/dev/null
  for _ in $(seq 1 60); do curl -sf "http://127.0.0.1:${HOST_PORT}/" >/dev/null 2>&1 && break || sleep 1; done
  echo "== API Health (Docker) =="; curl -fsS "http://127.0.0.1:${HOST_PORT}/" || true; echo
else
  nohup bash -lc "source '$APP_DIR/.venv-host/bin/activate'; HOST_PORT='$HOST_PORT' USDT_CONTRACT_ADDRESS='$USDT_CONTRACT_ADDRESS' python '$APP_DIR/app.py'" >/dev/null 2>&1 &
  for _ in $(seq 1 60); do curl -sf "http://127.0.0.1:${HOST_PORT}/" >/dev/null 2>&1 && break || sleep 1; done
  echo "== API Health (Host) =="; curl -fsS "http://127.0.0.1:${HOST_PORT}/" || true; echo
fi
echo "[OK] Hazir. CLI calistirmak icin:"
echo "source \"$APP_DIR/.venv-host/bin/activate\" && export USDT_CONTRACT_ADDRESS=\"$USDT_CONTRACT_ADDRESS\" && python \"$SCRIPTS_DIR/usdt_transfer_cli.py\""