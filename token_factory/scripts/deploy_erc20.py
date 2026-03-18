#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from token_factory.config import TokenFactoryConfig
from token_factory.scripts.common import manifest_write, utc_ts
from token_factory.scripts.compile_token import compile_contract


def main() -> None:
    from eth_account import Account
    from web3 import Web3

    root = Path(__file__).resolve().parents[2]
    config = TokenFactoryConfig(root=root)

    if not config.evm_rpc_url:
        raise SystemExit("MISSING:EVM_RPC_URL")
    if not config.evm_private_key:
        raise SystemExit("MISSING:EVM_PRIVATE_KEY")

    compiled = compile_contract(config, "QuantumERC20Token.sol", "QuantumERC20Token")
    w3 = Web3(Web3.HTTPProvider(config.evm_rpc_url))
    if not w3.is_connected():
        raise SystemExit("EVM_RPC_NOT_CONNECTED")

    deployer = Account.from_key(config.evm_private_key)
    owner = config.token_owner or deployer.address
    contract = w3.eth.contract(abi=compiled["abi"], bytecode=compiled["bytecode"])

    tx = contract.constructor(
        config.token_name,
        config.token_symbol,
        config.token_decimals,
        config.token_initial_supply,
        Web3.to_checksum_address(owner),
        config.token_mintable,
        config.token_burnable,
        config.token_pausable,
    ).build_transaction(
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

    payload = {
        "ok": True,
        "chain_type": "erc20",
        "contract_name": "QuantumERC20Token",
        "token_name": config.token_name,
        "token_symbol": config.token_symbol,
        "token_decimals": config.token_decimals,
        "token_initial_supply": config.token_initial_supply,
        "owner": owner,
        "deployer": deployer.address,
        "contract_address": receipt.contractAddress,
        "transaction_hash": receipt.transactionHash.hex(),
        "block_number": int(receipt.blockNumber),
        "deployed_at_ts": utc_ts(),
        "rpc_url": config.evm_rpc_url,
        "chain_id": config.evm_chain_id,
        "build_file": str(config.build_dir / "QuantumERC20Token.json"),
    }

    manifest_path = config.manifests_dir / f"erc20_deploy_{config.token_symbol.lower()}.json"
    manifest_write(manifest_path, payload)
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
