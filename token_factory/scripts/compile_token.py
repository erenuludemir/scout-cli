#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from token_factory.config import TokenFactoryConfig


def compile_contract(config: TokenFactoryConfig, contract_file: str, contract_name: str) -> dict:
    from solcx import compile_standard, install_solc, set_solc_version

    install_solc(config.solc_version)
    set_solc_version(config.solc_version)

    source_path = config.contracts_dir / contract_file
    source_code = source_path.read_text(encoding="utf-8")

    compiled = compile_standard(
        {
            "language": "Solidity",
            "sources": {
                contract_file: {
                    "content": source_code,
                }
            },
            "settings": {
                "optimizer": {"enabled": True, "runs": 200},
                "outputSelection": {
                    "*": {
                        "*": [
                            "abi",
                            "metadata",
                            "evm.bytecode",
                            "evm.deployedBytecode",
                        ]
                    }
                },
            },
        }
    )

    contract_data = compiled["contracts"][contract_file][contract_name]
    output = {
        "contract_name": contract_name,
        "contract_file": contract_file,
        "abi": contract_data["abi"],
        "bytecode": contract_data["evm"]["bytecode"]["object"],
        "deployed_bytecode": contract_data["evm"]["deployedBytecode"]["object"],
        "solc_version": config.solc_version,
    }

    out_path = config.build_dir / f"{contract_name}.json"
    out_path.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    return output


def main() -> None:
    root = Path(__file__).resolve().parents[2]
    config = TokenFactoryConfig(root=root)
    if config.chain_type == "trc20":
        result = compile_contract(config, "QuantumTRC20Token.sol", "QuantumTRC20Token")
    else:
        result = compile_contract(config, "QuantumERC20Token.sol", "QuantumERC20Token")
    build_file = config.build_dir / f'{result["contract_name"]}.json'
    print(
        json.dumps(
            {"ok": True, "build_file": str(build_file)},
            ensure_ascii=False,
            indent=2,
        )
    )


if __name__ == "__main__":
    main()
