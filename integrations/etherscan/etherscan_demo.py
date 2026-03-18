import os, json
from decimal import Decimal
from .etherscan_client import EtherscanClient

def wei_to_eth(wei: int) -> str:
    return str(Decimal(wei) / Decimal(10**18))

def main():
    addr = os.getenv("ETH_ADDRESS", "").strip()
    if not addr:
        raise SystemExit("Set ETH_ADDRESS in environment/.env")
    cli = EtherscanClient()
    bal_wei = cli.get_balance_wei(addr)
    txs = cli.get_txlist(addr, page=1, offset=5, sort="desc")
    print(json.dumps({
        "address": addr,
        "balance_wei": bal_wei,
        "balance_eth": wei_to_eth(bal_wei),
        "last_5_txs": txs
    }, indent=2))

if __name__ == "__main__":
    main()
