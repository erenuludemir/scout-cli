from flask import Flask, request, jsonify
from web3 import Web3
from dotenv import load_dotenv
import os
import time

load_dotenv()

app = Flask(__name__)

# Environment / configuration
RPC_URL = os.getenv("RPC_URL", "https://ethereum.publicnode.com")
INFURA_PROJECT_ID = os.getenv("INFURA_PROJECT_ID")
if INFURA_PROJECT_ID and not RPC_URL.startswith("http"):
    RPC_URL = f"https://mainnet.infura.io/v3/{INFURA_PROJECT_ID}"

PRIVATE_KEY = (os.getenv("PRIVATE_KEY", "") or "").strip()
SENDER_ADDRESS = os.getenv("WALLET_ADDRESS", "0xda93812D7D1F3D326ef8156D94175238948Da04f")

web3 = Web3(Web3.HTTPProvider(RPC_URL))

USDT_CONTRACT_ADDRESS = Web3.to_checksum_address("0xdAC17F958D2ee523a2206206994597C13D831ec7")
USDT_ABI = [
    {"constant": False, "inputs": [{"name": "_to", "type": "address"}, {"name": "_value", "type": "uint256"}], "name": "transfer", "outputs": [{"name": "success", "type": "bool"}], "type": "function"}
]
contract = web3.eth.contract(address=USDT_CONTRACT_ADDRESS, abi=USDT_ABI)
_started = time.time()

# Optional blueprint registration (guarded)
try:
    from integrations.etherscan.flask_ext import bp as etherscan_bp  # type: ignore
    app.register_blueprint(etherscan_bp)
except Exception as e:  # pragma: no cover
    app.logger.warning(f"[etherscan] blueprint skip: {e}")
@app.get("/health")
def health():
    try:
        return jsonify(ok=True,service="quantumai-usdt",block=web3.eth.block_number,ready=(time.time()-_started)>0.5)
    except Exception as e:
        return jsonify(ok=False,error=str(e)),500
@app.get("/dex/health")
def dex_health(): return jsonify(ok=True,service="dex",ready=(time.time()-_started)>0.5)
@app.post("/dex/swap")
def swap_demo():
    try:
        data = request.get_json(force=True) or {}
        f = (data.get("from_token") or "").upper()
        t = (data.get("to_token") or "").upper()
        amt = float(data.get("amount_in", 0))
        sl = int(data.get("slippage_bps", 50))
        if not f or not t or amt <= 0:
            return jsonify(status="error", message="from_token/to_token/amount_in required"), 400
        if (f, t) == ("ETH", "USDT"):
            price = 3000.0
        elif (f, t) == ("USDT", "ETH"):
            price = 1 / 3000.0
        else:
            price = 1.0
        out = amt * price
        out_min = out * (1 - sl / 10000.0)
        return jsonify(status="ok", route="demo", from_token=f, to_token=t, amount_in=amt,
                       quote_out=out, min_out=out_min, slippage_bps=sl)
    except Exception as e:
        return jsonify(status="error",message=str(e)),500
@app.post("/transfer")
def transfer():
    try:
        if not PRIVATE_KEY or SENDER_ADDRESS=="0xda93812D7D1F3D326ef8156D94175238948Da04f":
            return jsonify(status="error",message="Wallet not configured"),400
        d=request.get_json(force=True) or {}
        recipient = Web3.to_checksum_address(d.get("recipient"))
        amount = int(d.get("amount"))
        if amount <= 0:
            return jsonify(status="error", message="amount must be > 0"), 400
        nonce = web3.eth.get_transaction_count(SENDER_ADDRESS)
        gas_price = web3.eth.gas_price
        gas_limit = 90000
        tx=contract.functions.transfer(recipient,amount).build_transaction({
            "chainId":web3.eth.chain_id,"from":SENDER_ADDRESS,"gas":gas_limit,"gasPrice":gas_price,"nonce":nonce
        })
        signed=web3.eth.account.sign_transaction(tx,private_key=PRIVATE_KEY)
        if os.getenv("GLI_DRY_RUN","0")=="0":
            return jsonify(status="preview",from_=SENDER_ADDRESS,to=recipient,amount=amount,
                           fee_eth=float(Web3.from_wei(gas_price*gas_limit,'ether')),
                           raw_tx=signed.rawTransaction.hex(),tx_hash_computed=signed.hash.hex())
        tx_hash=web3.eth.send_raw_transaction(signed.rawTransaction)
        return jsonify(status="sent",from_=SENDER_ADDRESS,to=recipient,amount=amount,
                       fee_eth=float(Web3.from_wei(gas_price*gas_limit,'ether')),tx_hash=tx_hash.hex())
    except Exception as e:
        return jsonify(status="error",message=str(e)),500
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002)
