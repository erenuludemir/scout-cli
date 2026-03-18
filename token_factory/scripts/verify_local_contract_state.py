#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from token_factory.config import TokenFactoryConfig


def verify_evm(config: TokenFactoryConfig) -> dict:
    from web3 import Web3

    manifest_path = config.manifests_dir / f"erc20_deploy_{config.token_symbol.lower()}.json"
    build_path = config.build_dir / "QuantumERC20Token.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    build = json.loads(build_path.read_text(encoding="utf-8"))

    w3 = Web3(Web3.HTTPProvider(config.evm_rpc_url))
    contract = w3.eth.contract(address=Web3.to_checksum_address(manifest["contract_address"]), abi=build["abi"])
    owner = contract.functions.owner().call()
    total_supply = contract.functions.totalSupply().call()
    decimals = contract.functions.decimals().call()
    return {
        "ok": True,
        "chain_type": "erc20",
        "contract_address": manifest["contract_address"],
        "owner": owner,
        "total_supply_raw": str(total_supply),
        "decimals": decimals,
    }


def verify_tron(config: TokenFactoryConfig) -> dict:
    from tronpy import Tron
    from tronpy.providers import HTTPProvider

    manifest_path = config.manifests_dir / f"trc20_deploy_{config.token_symbol.lower()}.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    client = Tron(provider=HTTPProvider(endpoint_uri=config.tron_provider_url))
    contract = client.get_contract(manifest["contract_address"])
    owner = contract.functions.owner()
    total_supply = contract.functions.totalSupply()
    decimals = contract.functions.decimals()
    return {
        "ok": True,
        "chain_type": "trc20",
        "contract_address": manifest["contract_address"],
        "owner": owner,
        "total_supply_raw": str(total_supply),
        "decimals": decimals,
    }


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    config = TokenFactoryConfig(root=root)
    if config.chain_type == "trc20":
        print(json.dumps(verify_tron(config), ensure_ascii=False, indent=2))
    else:
        print(json.dumps(verify_evm(config), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
