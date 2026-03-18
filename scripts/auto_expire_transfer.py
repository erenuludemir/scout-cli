#!/usr/bin/env python3
"""
USDT Token Transfer & Expiry Mechanism - Production Instructions
"""
import os, sys, json, subprocess
from datetime import datetime, timedelta, timezone
from typing import Dict, Any, List
try:
    from web3 import Web3
    from dotenv import load_dotenv
except ImportError:
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'web3', 'python-dotenv'])
    from web3 import Web3
    from dotenv import load_dotenv

load_dotenv()
INFURA_URL   = os.getenv("INFURA_URL")
if not INFURA_URL and os.getenv("INFURA_PROJECT_ID"):
    INFURA_URL = f"https://mainnet.infura.io/v3/{os.getenv('INFURA_PROJECT_ID')}"
PRIVATE_KEY  = os.getenv("PRIVATE_KEY") or os.getenv("ETH_PRIVATE_KEY")
WALLET_ADDR  = os.getenv("WALLET_ADDRESS") or os.getenv("ETH_SENDER_ADDRESS")
CHAIN_ID     = 1
TOKEN_DECIMALS = 6
USDT_CONTRACT_ADDRESS = "0xdAC17F958D2ee523a2206206994597C13D831ec7"
DEPLOYED_CONTRACTS_FILE = "./deployed_contracts.json"

w3 = Web3(Web3.HTTPProvider(INFURA_URL))
if not w3.is_connected():
    print("[!] Unable to establish Web3 connection."); sys.exit(1)
account = w3.eth.account.from_key(PRIVATE_KEY)
print(f"[+] Wallet: {account.address}")

ERC20_ABI: List[Dict[str, Any]] = [
    {"constant":True,"inputs":[{"name":"_owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"balance","type":"uint256"}],"type":"function"},
    {"constant":False,"inputs":[{"name":"_to","type":"address"},{"name":"_value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"},
]
def check_eth_balance(min_eth: float = 0.002) -> bool:
    try:
        wei_balance = w3.eth.get_balance(account.address)
        eth_balance = w3.from_wei(wei_balance, 'ether')
        print(f"[ℹ️] ETH balance: {eth_balance:.6f} ETH")
        return eth_balance >= min_eth
    except Exception as exc:
        print(f"[❌] Balance query error: {exc}"); return False

def transfer_token(contract_address: str, to_address: str, amount_usdt: float, expire_days: int = 7) -> bytes:
    if not check_eth_balance(): raise Exception("Insufficient ETH balance for gas fees")
    checksum_address = w3.to_checksum_address(contract_address)
    contract = w3.eth.contract(address=checksum_address, abi=ERC20_ABI)
    amount = int(amount_usdt * (10 ** TOKEN_DECIMALS))

    usdt_balance = contract.functions.balanceOf(account.address).call()
    if usdt_balance < amount:
        raise Exception(f"Insufficient USDT balance. Have: {usdt_balance/(10**TOKEN_DECIMALS):.2f}, Need: {amount_usdt:.2f}")

    nonce = w3.eth.get_transaction_count(account.address)
    tx = contract.functions.transfer(w3.to_checksum_address(to_address), amount).build_transaction({
        'chainId': CHAIN_ID,'gas': 80000,'gasPrice': w3.to_wei('20', 'gwei'),'nonce': nonce})
    signed_tx = w3.eth.account.sign_transaction(tx, private_key=PRIVATE_KEY)
    raw_tx = getattr(signed_tx, 'raw_transaction', None) or getattr(signed_tx, 'rawTransaction', None)
    if raw_tx is None: raise Exception("Could not access signed transaction data")
    tx_hash = w3.eth.send_raw_transaction(raw_tx)
    print(f"[+] Transfer initiated. Hash: {w3.to_hex(tx_hash)}")

    expire_at = datetime.now(timezone.utc) + timedelta(days=expire_days)
    record: Dict[str, Any] = {
        "contract": contract_address,"to": to_address,"amount_usdt": amount_usdt,
        "tx_hash": w3.to_hex(tx_hash),"expire_at": expire_at.strftime("%Y-%m-%d %H:%M:%S"),
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")}
    data: List[Dict[str, Any]] = []
    try:
        if os.path.exists(DEPLOYED_CONTRACTS_FILE):
            with open(DEPLOYED_CONTRACTS_FILE, 'r', encoding='utf-8') as f:
                loaded = json.load(f); data = loaded if isinstance(loaded, list) else []
    except Exception: data = []
    data.append(record)
    with open(DEPLOYED_CONTRACTS_FILE, 'w', encoding='utf-8') as f: json.dump(data, f, indent=4)
    return tx_hash

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 auto_expire_transfer.py RECEIVER_ADDRESS AMOUNT [DAYS]"); sys.exit(1)
    recipient = sys.argv[1]; amount = float(sys.argv[2]); days = int(sys.argv[3]) if len(sys.argv) > 3 else 7
    transfer_token(USDT_CONTRACT_ADDRESS, recipient, amount, days)
