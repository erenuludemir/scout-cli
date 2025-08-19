from flask import Flask, request, jsonify
from web3 import Web3
from dotenv import load_dotenv
import os, time, json, asyncio

try:
    from etherscan_v2_client import EtherscanV2Client
except Exception:
    EtherscanV2Client = None

async def _get_eth_usd_async() -> float | None:
    if EtherscanV2Client is None:
        return None
    try:
        async with EtherscanV2Client(chain_id=1) as cli:
            return await cli.get_eth_price()
    except Exception:
        return None

def get_eth_usd() -> float | None:
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
USDT   = Web3.to_checksum_address("0xdAC17F958D2ee523a2206206994597C13D831ec7")

ERC20_ABI = [
  {"constant":False,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"},
  {"constant":True,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"},
  {"constant":True,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"},
  {"constant":True,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"type":"function"},
]
erc20 = w3.eth.contract(address=USDT, abi=ERC20_ABI)
app = Flask(__name__)

def _mwei_to_float(n):
  return float(Web3.from_wei(n, "mwei"))

@app.get("/")
def root():
  return {"ok": True, "network":"ethereum-mainnet", "sender": SENDER}

@app.post("/estimate")
def estimate():
  try:
    data = request.get_json(force=True) or {}
    recipient_raw = data.get("recipient")
    amount_6 = int(data.get("amount", 0))
    if not recipient_raw or amount_6 <= 0:
      return jsonify({"status":"error","message":"recipient/amount required"}), 400
    recipient = Web3.to_checksum_address(recipient_raw)
    value_usdt = Web3.to_wei(amount_6, "mwei")

    nonce = w3.eth.get_transaction_count(SENDER)
    gas_price = w3.eth.gas_price
    tx = erc20.functions.transfer(recipient, value_usdt).build_transaction({
      "chainId": 1, "from": SENDER, "nonce": nonce,
    })

    try:
      gas_estimate = w3.eth.estimate_gas({"from": SENDER, "to": USDT, "data": tx.get("data")})
    except Exception:
      gas_estimate = 60000

    fee_wei = gas_price * gas_estimate
    fee_eth = Web3.from_wei(fee_wei, "ether")
    eth_usd = get_eth_usd()

    return jsonify({
      "status":"ok",
      "chain":"ethereum-mainnet",
      "token":"USDT",
      "decimals":6,
      "from": SENDER,
      "to": recipient,
      "amount_usdt_6": amount_6,
      "amount_usdt_human": amount_6/1_000_000.0,
      "gas_price_wei": int(gas_price),
      "gas_used_estimate": int(gas_estimate),
      "fee_eth": float(fee_eth),
      "eth_usd": eth_usd,
      "fee_usd_estimate": (float(fee_eth)*eth_usd) if eth_usd else None,
      "notes":"Estimate only; final usage may vary."
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
    value_usdt = Web3.to_wei(amount_6, "mwei")

    nonce = w3.eth.get_transaction_count(SENDER)
    gas_price = w3.eth.gas_price
    built = erc20.functions.transfer(recipient, value_usdt).build_transaction({
      "chainId": 1, "from": SENDER, "nonce": nonce, "gas": 120000, "gasPrice": gas_price
    })
    signed = w3.eth.account.sign_transaction(built, private_key=PRIV)
    raw_hex = signed.rawTransaction.hex()
    hash_hex = Web3.to_hex(Web3.keccak(signed.rawTransaction))

    if os.getenv("GLI_DRY_RUN", "1") == "1":
      return jsonify({
        "status":"preview",
        "tx_hash_computed": hash_hex,
        "raw_tx": raw_hex,
        "gas_price_wei": int(gas_price),
        "gas_limit": int(built.get("gas", 0)),
        "fee_estimate_eth": float(Web3.from_wei(gas_price * built.get("gas", 0), "ether")),
        "note":"Set GLI_DRY_RUN=0 to broadcast"
      })

    tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)
    th = Web3.to_hex(tx_hash)
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)
    block = w3.eth.get_block(receipt.blockNumber)
    eff = getattr(receipt, "effectiveGasPrice", gas_price)
    burnt = 0
    base = getattr(block, "baseFeePerGas", None)
    if base is not None and eff is not None:
      burnt = base * receipt.gasUsed

    sender_eth = w3.from_wei(w3.eth.get_balance(SENDER), "ether")
    try:
      usdt_sender = _mwei_to_float(erc20.functions.balanceOf(SENDER).call())
      usdt_rec   = _mwei_to_float(erc20.functions.balanceOf(recipient).call())
    except Exception:
      usdt_sender = None; usdt_rec = None

    details = {
      "network":"ethereum-mainnet",
      "status":"success" if receipt.status==1 else "reverted",
      "tx_hash": th,
      "block_number": receipt.blockNumber,
      "timestamp": block.timestamp,
      "from": SENDER,
      "to": recipient,
      "contract": USDT,
      "value_usdt_6dec": amount_6,
      "value_usdt_human": amount_6/1_000_000.0,
      "transaction_fee_eth": float(Web3.from_wei(eff * receipt.gasUsed, "ether")),
      "gas_price_wei": int(eff),
      "gas_limit": int(built.get("gas", 0)),
      "gas_used": int(receipt.gasUsed),
      "burnt_fees_wei": int(burnt),
      "other_attributes": {"type": "ERC20.transfer","input_data": built.get("data")},
      "balances": {
        "sender_eth": float(sender_eth),
        "sender_usdt_after": float(usdt_sender) if usdt_sender is not None else None,
        "recipient_usdt_after": float(usdt_rec) if usdt_rec is not None else None
      }
    }
    try:
      os.makedirs("/app/logs", exist_ok=True)
      with open(f"/app/logs/tx_{int(time.time())}.json","w") as f:
        json.dump(details, f, indent=2)
    except Exception:
      pass

    return jsonify(details)
  except Exception as e:
    return jsonify({"status":"error","message":str(e)}), 500

if __name__ == "__main__":
  app.run(host="0.0.0.0", port=5002)
