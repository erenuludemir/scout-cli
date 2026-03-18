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
    from tronpy import Tron
    from tronpy.keys import PrivateKey
    from tronpy.providers import HTTPProvider

    root = Path(__file__).resolve().parents[2]
    config = TokenFactoryConfig(root=root)

    if not config.tron_private_key:
        raise SystemExit("MISSING:TRON_PRIVATE_KEY")

    compiled = compile_contract(config, "QuantumTRC20Token.sol", "QuantumTRC20Token")

    client = Tron(provider=HTTPProvider(endpoint_uri=config.tron_provider_url))
    private_key = PrivateKey(bytes.fromhex(config.tron_private_key))
    owner_addr = config.token_owner or private_key.public_key.to_base58check_address()

    contract = (
        client.trx.deploy_contract(
            owner=private_key.public_key.to_base58check_address(),
            abi=compiled["abi"],
            bytecode=compiled["bytecode"],
            fee_limit=config.tron_fee_limit,
            call_value=0,
            consume_user_resource_percent=100,
            name="QuantumTRC20Token",
            origin_energy_limit=10_000_000,
            params=[
                config.token_name,
                config.token_symbol,
                config.token_decimals,
                config.token_initial_supply,
                owner_addr,
                config.token_mintable,
                config.token_burnable,
                config.token_pausable,
            ],
        )
        .build()
        .sign(private_key)
        .broadcast()
        .wait()
    )

    payload = {
        "ok": True,
        "chain_type": "trc20",
        "contract_name": "QuantumTRC20Token",
        "token_name": config.token_name,
        "token_symbol": config.token_symbol,
        "token_decimals": config.token_decimals,
        "token_initial_supply": config.token_initial_supply,
        "owner": owner_addr,
        "deployer": private_key.public_key.to_base58check_address(),
        "contract_address": contract["contract_address"],
        "transaction_hash": contract["txid"],
        "deployed_at_ts": utc_ts(),
        "tron_provider_url": config.tron_provider_url,
        "tron_network": config.tron_network,
        "build_file": str(config.build_dir / "QuantumTRC20Token.json"),
    }

    manifest_path = config.manifests_dir / f"trc20_deploy_{config.token_symbol.lower()}.json"
    manifest_write(manifest_path, payload)
    print(json.dumps(payload, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
