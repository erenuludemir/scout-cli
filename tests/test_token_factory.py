from __future__ import annotations

import json
import sys
import types
from pathlib import Path

from token_factory.config import TokenFactoryConfig
from token_factory.scripts.common import manifest_write, read_distribution_csv
from token_factory.scripts.compile_token import compile_contract


def test_config_creates_build_manifest_and_distribution_dirs(tmp_path):
    config = TokenFactoryConfig(root=tmp_path)
    assert config.build_dir.exists()
    assert config.manifests_dir.exists()
    assert config.distributions_dir.exists()
    assert config.contracts_dir == tmp_path / "token_factory" / "contracts"


def test_read_distribution_csv_filters_invalid_rows(tmp_path):
    csv_path = tmp_path / "dist.csv"
    csv_path.write_text(
        "address,amount\n"
        "0x1111111111111111111111111111111111111111,10\n"
        ",5\n"
        "0x2222222222222222222222222222222222222222,0\n"
        "0x3333333333333333333333333333333333333333,15\n",
        encoding="utf-8",
    )

    rows = read_distribution_csv(csv_path)
    assert rows == [
        {"address": "0x1111111111111111111111111111111111111111", "amount": 10},
        {"address": "0x3333333333333333333333333333333333333333", "amount": 15},
    ]


def test_manifest_write_persists_json(tmp_path):
    manifest_path = tmp_path / "nested" / "manifest.json"
    payload = {"ok": True, "symbol": "QAIT"}
    manifest_write(manifest_path, payload)
    assert json.loads(manifest_path.read_text(encoding="utf-8")) == payload


def test_compile_contract_writes_build_artifact(tmp_path, monkeypatch):
    contracts_dir = tmp_path / "token_factory" / "contracts"
    contracts_dir.mkdir(parents=True, exist_ok=True)
    (contracts_dir / "QuantumERC20Token.sol").write_text("pragma solidity ^0.8.24; contract QuantumERC20Token {}", encoding="utf-8")

    fake_solcx = types.ModuleType("solcx")
    calls: list[tuple[str, str]] = []

    def install_solc(version: str) -> None:
        calls.append(("install", version))

    def set_solc_version(version: str) -> None:
        calls.append(("set", version))

    def compile_standard(spec: dict) -> dict:
        assert "QuantumERC20Token.sol" in spec["sources"]
        return {
            "contracts": {
                "QuantumERC20Token.sol": {
                    "QuantumERC20Token": {
                        "abi": [{"type": "constructor"}],
                        "evm": {
                            "bytecode": {"object": "0x6000"},
                            "deployedBytecode": {"object": "0x6001"},
                        },
                    }
                }
            }
        }

    fake_solcx.install_solc = install_solc
    fake_solcx.set_solc_version = set_solc_version
    fake_solcx.compile_standard = compile_standard
    monkeypatch.setitem(sys.modules, "solcx", fake_solcx)

    config = TokenFactoryConfig(root=tmp_path)
    result = compile_contract(config, "QuantumERC20Token.sol", "QuantumERC20Token")

    assert result["contract_name"] == "QuantumERC20Token"
    assert result["bytecode"] == "0x6000"
    build_file = config.build_dir / "QuantumERC20Token.json"
    assert build_file.exists()
    assert ("install", config.solc_version) in calls
    assert ("set", config.solc_version) in calls
