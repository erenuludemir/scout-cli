#!/usr/bin/env python3
"""
Sağlam gas kontrolü + canlı gas fiyatı kullanan USDT göndericisi
"""
import sys, os, json
from decimal import Decimal
from dotenv import load_dotenv
from web3 import Web3
from eth_account import Account

ENV_PATH = os.getenv("ENV_PATH") or (
    "~/Library/Mobile Documents/com~apple~CloudDocs/QuantumAI-Blockchain-Panel/usdt_env/.env"
)
load_dotenv(os.path.expanduser(ENV_PATH))

INFURA_URL     = os.getenv("INFURA_URL") or (f"https://mainnet.infura.io/v3/{os.getenv('INFURA_PROJECT_ID')}" if os.getenv("INFURA_PROJECT_ID") else None)
PRIVATE_KEY    = os.getenv("PRIVATE_KEY") or os.getenv("ETH_PRIVATE_KEY")
RECEIVER_ENV   = os.getenv("RECEIVER") or os.getenv("ETH_RECIPIENT_ADDRESS")
USDT_CONTRACT  = os.getenv("USDT_CONTRACT") or "0xdAC17F958D2ee523a2206206994597C13D831ec7"

def as_decimal(value, default):
    try: return Decimal(str(value))
    except Exception: return Decimal(default)

USDT_AMOUNT   = as_decimal(sys.argv[1] if len(sys.argv)>1 else "10", "10")
GAS_PRICE_GWEI= as_decimal(sys.argv[2] if len(sys.argv)>2 else "19", "19")

w3       = Web3(Web3.HTTPProvider(INFURA_URL))
account  = Account.from_key(PRIVATE_KEY)
USDT_ABI = json.loads('[{"constant":true,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"}]')
usdt = w3.eth.contract(address=Web3.to_checksum_address(USDT_CONTRACT), abi=USDT_ABI)
DECIMALS = 10 ** 6

def main() -> None:
    amount_raw = int(USDT_AMOUNT * DECIMALS)
    nonce      = w3.eth.get_transaction_count(account.address)
    gas_limit  = usdt.functions.transfer(Web3.to_checksum_address(RECEIVER_ENV), amount_raw).estimate_gas({"from": account.address}) + 5000
    gas_price  = w3.to_wei(GAS_PRICE_GWEI, "gwei")
    required   = gas_limit * gas_price
    balance    = w3.eth.get_balance(account.address)
    if balance < required:
        need = w3.from_wei(required, "ether"); have = w3.from_wei(balance, "ether")
        raise SystemExit(f"❌ Yetersiz ETH! Gerekli ≈ {need:.6f} ETH, var {have:.6f} ETH.")
    tx = usdt.functions.transfer(Web3.to_checksum_address(RECEIVER_ENV), amount_raw).build_transaction({
        "chainId": 1,"from": account.address,"nonce": nonce,"gas": gas_limit,"gasPrice": gas_price})
    signed = w3.eth.account.sign_transaction(tx, PRIVATE_KEY)
    tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)
    print("-----------------------------------------------------------")
    print(f"🚀  Tx: https://etherscan.io/tx/{tx_hash.hex()}")
    print(f"💵  USDT       : {USDT_AMOUNT}")
    print(f"⛽  Gas limiti : {gas_limit}")
    print(f"⛽  Gas fiyatı : {GAS_PRICE_GWEI} Gwei")
    fee_eth = w3.from_wei(required, 'ether')
    print(f"💸  Maks. ücret: {fee_eth:.6f} ETH")
    print("-----------------------------------------------------------")

if __name__ == "__main__":
    try: main()
    except Exception as exc:
        print(f"❌  Hata: {exc}"); sys.exit(1)
