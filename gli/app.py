from __future__ import annotations

from typing import Any, Dict, Optional
from flask import Flask, request, jsonify
from web3 import Web3
from dotenv import load_dotenv
import os

load_dotenv()

def pick_provider() -> str:
    """Choose RPC: FLASHBOOT(if enabled) -> INFURA_URL -> INFURA_PROJECT_ID."""
    use_fb = os.getenv("USE_FLASHBOOT", "0") == "1"
    fb_url = (os.getenv("FLASHBOOT_RPC_URL") or "").strip()
    if use_fb and fb_url:
        return fb_url

    infura = (os.getenv("INFURA_URL") or "").strip()
    if infura:
        return infura

    pid = (os.getenv("INFURA_PROJECT_ID") or "").strip()
    if pid:
        return f"https://mainnet.infura.io/v3/{pid}"

    raise RuntimeError(
        "No RPC configured. Set FLASHBOOT_RPC_URL or INFURA_URL or INFURA_PROJECT_ID"
    )

RPC: str = pick_provider()
w3: Web3 = Web3(Web3.HTTPProvider(RPC))

SENDER_RAW: Optional[str] = os.getenv("ETH_SENDER_ADDRESS") or os.getenv("WALLET_ADDRESS")
PRIV: Optional[str] = os.getenv("ETH_PRIVATE_KEY")
if not SENDER_RAW or not PRIV:
    raise RuntimeError("ETH_SENDER_ADDRESS / ETH_PRIVATE_KEY missing in environment")

SENDER = Web3.to_checksum_address(SENDER_RAW)

USDT = Web3.to_checksum_address("0xdAC17F958D2ee523a2206206994597C13D831ec7")

ERC20_ABI: list[dict[str, Any]] = [
    {
        "constant": False,
        "inputs": [{"name": "_to", "type": "address"}, {"name": "_value", "type": "uint256"}],
        "name": "transfer",
        "outputs": [{"name": "", "type": "bool"}],
        "type": "function",
    },
    {
        "constant": True,
        "inputs": [{"name": "_owner", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "balance", "type": "uint256"}],
        "type": "function",
    },
    {
        "constant": False,
        "inputs": [{"name": "_spender", "type": "address"}, {"name": "_value", "type": "uint256"}],
        "name": "approve",
        "outputs": [{"name": "", "type": "bool"}],
        "type": "function",
    },
]
erc20 = w3.eth.contract(address=USDT, abi=ERC20_ABI)

app = Flask(__name__)

@app.get("/")
def root() -> Dict[str, Any]:
    mask = RPC[:50] + "..." if len(RPC) > 50 else RPC
    return {"ok": True, "rpc": mask, "sender": SENDER}

def _eip1559_fees(mult: float = 1.0) -> Dict[str, int]:
    """Return gas dict: EIP-1559 if available else legacy gasPrice."""
    latest = w3.eth.get_block("latest")
    base = latest.get("baseFeePerGas") if isinstance(latest, dict) else getattr(latest, "baseFeePerGas", None)

    try:
        prio = int(w3.eth.max_priority_fee)
    except Exception:
        prio = int(Web3.to_wei(2, "gwei"))
    prio = int(prio * mult)

    if base is None:
        gas_price = int(w3.eth.gas_price * mult)
        return {"type": 0, "gasPrice": gas_price}

    max_fee = int(int(base) * 2 + prio)
    return {"type": 2, "maxFeePerGas": max_fee, "maxPriorityFeePerGas": prio}

@app.post("/estimate")
def estimate():
    try:
        d: Dict[str, Any] = request.get_json(force=True) or {}
        to_raw = d.get("recipient")
        amt_6 = int(d.get("amount", 0))
        mult = float(d.get("gas_mult", 1)) or 1.0
        if not to_raw or amt_6 <= 0:
            return jsonify({"status": "error", "message": "recipient/amount required"}), 400

        to = Web3.to_checksum_address(str(to_raw))
        val = Web3.to_wei(amt_6, "mwei")  # 6 decimals

        try:
            gas = erc20.functions.transfer(to, val).estimate_gas({"from": SENDER})
        except Exception:
            gas = 60000

        fees = _eip1559_fees(mult)
        price = int(fees.get("gasPrice") or fees.get("maxFeePerGas") or 0)
        fee_eth = float(Web3.from_wei(price * int(gas), "ether"))

        return jsonify({
            "status": "ok",
            "from": SENDER,
            "to": to,
            "amount_usdt_6": amt_6,
            "gas_used_estimate": int(gas),
            "gas_price_wei": int(fees.get("gasPrice", 0)) or None,
            "maxFeePerGas_wei": int(fees.get("maxFeePerGas", 0)) or None,
            "maxPriorityFeePerGas_wei": int(fees.get("maxPriorityFeePerGas", 0)) or None,
            "fee_eth": fee_eth,
            "gas_mult_applied": mult,
        })
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.post("/approve")
def approve():
    try:
        d: Dict[str, Any] = request.get_json(force=True) or {}
        spender = Web3.to_checksum_address(d.get("spender") or SENDER)
        amt = d.get("amount", "unlimited")
        mult = float(d.get("gas_mult", 1)) or 1.0
        allowance = (1 << 256) - 1 if str(amt).lower() in {"unlimited", "max", "infinite"} else int(amt)

        try:
            gas_est = erc20.functions.approve(spender, allowance).estimate_gas({"from": SENDER})
        except Exception:
            gas_est = 55000

        gas_limit = int(max(55000, min(int(gas_est * 1.2), 200000)))
        nonce = w3.eth.get_transaction_count(SENDER)
        fees = _eip1559_fees(mult)

        built = erc20.functions.approve(spender, allowance).build_transaction({
            "chainId": 1,
            "from": SENDER,
            "nonce": nonce,
            "gas": gas_limit,
            **(
                {"gasPrice": int(fees["gasPrice"])}
                if "gasPrice" in fees
                else {
                    "type": 2,
                    "maxFeePerGas": int(fees["maxFeePerGas"]),
                    "maxPriorityFeePerGas": int(fees["maxPriorityFeePerGas"]),
                }
            ),
        })

        signed = w3.eth.account.sign_transaction(built, private_key=str(PRIV))

        if os.getenv("GLI_DRY_RUN", "1") == "1":
            eff = int(built.get("gasPrice") or built.get("maxFeePerGas") or 0)
            return jsonify({
                "status": "preview",
                "action": "approve",
                "spender": spender,
                "gas_limit": int(built["gas"]),
                "gas_price_wei": int(built.get("gasPrice", 0)) or None,
                "maxFeePerGas_wei": int(built.get("maxFeePerGas", 0)) or None,
                "maxPriorityFeePerGas_wei": int(built.get("maxPriorityFeePerGas", 0)) or None,
                "fee_estimate_eth": float(Web3.from_wei(eff * int(built["gas"]), "ether")),
                "gas_mult_applied": mult,
                "raw_tx": signed.rawTransaction.hex(),
            })

        tx = w3.eth.send_raw_transaction(signed.rawTransaction)
        rc = w3.eth.wait_for_transaction_receipt(tx, timeout=180)
        return jsonify({"status": "success" if rc.status == 1 else "reverted", "tx_hash": w3.to_hex(tx), "block": rc.blockNumber})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.post("/transfer")
def transfer():
    try:
        d: Dict[str, Any] = request.get_json(force=True) or {}
        to_raw = d.get("recipient")
        amt_6 = int(d.get("amount", 0))
        mult = float(d.get("gas_mult", 1)) or 1.0
        if not to_raw or amt_6 <= 0:
            return jsonify({"status": "error", "message": "recipient/amount required"}), 400

        to = Web3.to_checksum_address(str(to_raw))
        val = Web3.to_wei(amt_6, "mwei")

        try:
            bal: Optional[int] = erc20.functions.balanceOf(SENDER).call()
        except Exception:
            bal = None

        if bal is not None and bal < val:
            return jsonify({
                "status": "error",
                "message": "insufficient USDT balance",
                "required_6": amt_6,
                "have_6": int(bal),
            }), 400

        try:
            gas_est = erc20.functions.transfer(to, val).estimate_gas({"from": SENDER})
        except Exception:
            gas_est = 60000

        gas_limit = int(max(60000, min(int(gas_est * 1.2), 200000)))
        nonce = w3.eth.get_transaction_count(SENDER)
        fees = _eip1559_fees(mult)

        built = erc20.functions.transfer(to, val).build_transaction({
            "chainId": 1,
            "from": SENDER,
            "nonce": nonce,
            "gas": gas_limit,
            **(
                {"gasPrice": int(fees["gasPrice"])}
                if "gasPrice" in fees
                else {
                    "type": 2,
                    "maxFeePerGas": int(fees["maxFeePerGas"]),
                    "maxPriorityFeePerGas": int(fees["maxPriorityFeePerGas"]),
                }
            ),
        })

        signed = w3.eth.account.sign_transaction(built, private_key=str(PRIV))

        if os.getenv("GLI_DRY_RUN", "1") == "1":
            eff = int(built.get("gasPrice") or built.get("maxFeePerGas") or 0)
            return jsonify({
                "status": "preview",
                "gas_limit": int(built["gas"]),
                "gas_price_wei": int(built.get("gasPrice", 0)) or None,
                "maxFeePerGas_wei": int(built.get("maxFeePerGas", 0)) or None,
                "maxPriorityFeePerGas_wei": int(built.get("maxPriorityFeePerGas", 0)) or None,
                "fee_estimate_eth": float(Web3.from_wei(eff * int(built["gas"]), "ether")),
                "gas_mult_applied": mult,
                "raw_tx": signed.rawTransaction.hex(),
            })

        tx = w3.eth.send_raw_transaction(signed.rawTransaction)
        rc = w3.eth.wait_for_transaction_receipt(tx, timeout=180)
        blk = w3.eth.get_block(rc.blockNumber)
        eff = getattr(rc, "effectiveGasPrice", built.get("gasPrice", 0))
        return jsonify({
            "status": "success" if rc.status == 1 else "reverted",
            "tx_hash": w3.to_hex(tx),
            "block_number": rc.blockNumber,
            "timestamp": blk.get("timestamp") if isinstance(blk, dict) else getattr(blk, "timestamp", None),
            "from": SENDER,
            "to": to,
            "contract": USDT,
            "value_usdt_6dec": amt_6,
            "gas_used": int(rc.gasUsed),
            "gas_limit": int(built["gas"]),
            "gas_price_wei": int(eff),
        })
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5002)