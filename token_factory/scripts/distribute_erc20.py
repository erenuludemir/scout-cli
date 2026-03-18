#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from token_factory.config import TokenFactoryConfig
from token_factory.scripts.common import read_distribution_csv


def main() -> None:
    from eth_account import Account
    from web3 import Web3

    root = Path(__file__).resolve().parents[2]
    config = TokenFactoryConfig(root=root)

    if not config.evm_rpc_url:
        raise SystemExit("MISSING:EVM_RPC_URL")
    if not config.evm_private_key:
        raise SystemExit("MISSING:EVM_PRIVATE_KEY")
    if not config.distribution_csv:
        raise SystemExit("MISSING:TOKEN_DISTRIBUTION_CSV")

    manifest_path = config.manifests_dir / f"erc20_deploy_{config.token_symbol.lower()}.json"
    build_path = config.build_dir / "QuantumERC20Token.json"
    if not manifest_path.exists():
        raise SystemExit(f"MISSING:{manifest_path}")
    if not build_path.exists():
        raise SystemExit(f"MISSING:{build_path}")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    build = json.loads(build_path.read_text(encoding="utf-8"))
    rows = read_distribution_csv(config.distribution_csv)
    if not rows:
        raise SystemExit("EMPTY_DISTRIBUTION")

    w3 = Web3(Web3.HTTPProvider(config.evm_rpc_url))
    if not w3.is_connected():
        raise SystemExit("EVM_RPC_NOT_CONNECTED")

    deployer = Account.from_key(config.evm_private_key)
    contract = w3.eth.contract(address=Web3.to_checksum_address(manifest["contract_address"]), abi=build["abi"])

    recipients = [Web3.to_checksum_address(row["address"]) for row in rows]
    amounts = [int(row["amount"]) for row in rows]

    tx = contract.functions.batchTransfer(recipients, amounts).build_transaction(
        {
            "from": deployer.address,
            "nonce": w3.eth.get_transaction_count(deployer.address),
            "chainId": config.evm_chain_id,
            "gas": config.evm_gas_limit,
            "maxFeePerGas": w3.to_wei(config.evm_max_fee_gwei, "gwei"),
            "maxPriorityFeePerGas": w3.to_wei(config.evm_priority_fee_gwei, "gwei"),
        }
    )

    signed = deployer.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed.raw_transaction)
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

    out = {
        "ok": True,
        "chain_type": "erc20",
        "token_symbol": config.token_symbol,
        "contract_address": manifest["contract_address"],
        "distribution_csv": str(config.distribution_csv),
        "recipient_count": len(recipients),
        "whole_units_total": sum(amounts),
        "tx_hash": receipt.transactionHash.hex(),
        "block_number": int(receipt.blockNumber),
    }
    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
