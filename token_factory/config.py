from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


def env(name: str, default: str = "") -> str:
    value = os.getenv(name)
    return value if value not in (None, "") else default


def env_int(name: str, default: int) -> int:
    try:
        return int(env(name, str(default)))
    except Exception:
        return default


def env_bool(name: str, default: bool) -> bool:
    raw = env(name, "1" if default else "0").strip().lower()
    return raw in {"1", "true", "yes", "on"}


@dataclass(slots=True)
class TokenFactoryConfig:
    root: Path
    solc_version: str = env("TOKEN_SOLC_VERSION", "0.8.24")
    chain_type: str = env("TOKEN_CHAIN_TYPE", "erc20").lower()
    token_name: str = env("TOKEN_NAME", "Quantum AI Token")
    token_symbol: str = env("TOKEN_SYMBOL", "QAIT")
    token_decimals: int = env_int("TOKEN_DECIMALS", 18)
    token_initial_supply: int = env_int("TOKEN_INITIAL_SUPPLY", 1_000_000)
    token_owner: str = env("TOKEN_OWNER_ADDRESS", "")
    token_mintable: bool = env_bool("TOKEN_MINTABLE", True)
    token_burnable: bool = env_bool("TOKEN_BURNABLE", True)
    token_pausable: bool = env_bool("TOKEN_PAUSABLE", True)

    evm_rpc_url: str = env("EVM_RPC_URL", "")
    evm_chain_id: int = env_int("EVM_CHAIN_ID", 1)
    evm_private_key: str = env("EVM_PRIVATE_KEY", "")
    evm_gas_limit: int = env_int("EVM_GAS_LIMIT", 3_500_000)
    evm_max_fee_gwei: int = env_int("EVM_MAX_FEE_GWEI", 30)
    evm_priority_fee_gwei: int = env_int("EVM_PRIORITY_FEE_GWEI", 2)

    tron_network: str = env("TRON_NETWORK", "nile")
    tron_provider_url: str = env("TRON_PROVIDER_URL", "https://api.nileex.io")
    tron_private_key: str = env("TRON_PRIVATE_KEY", "")
    tron_fee_limit: int = env_int("TRON_FEE_LIMIT", 2_000_000_000)

    distribution_csv: Path | None = None

    def __post_init__(self) -> None:
        csv_path = env("TOKEN_DISTRIBUTION_CSV", "")
        self.distribution_csv = Path(csv_path).resolve() if csv_path else None

    @property
    def contracts_dir(self) -> Path:
        return self.root / "token_factory" / "contracts"

    @property
    def build_dir(self) -> Path:
        path = self.root / "token_factory" / "build"
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def manifests_dir(self) -> Path:
        path = self.root / "token_factory" / "manifests"
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def distributions_dir(self) -> Path:
        path = self.root / "token_factory" / "distributions"
        path.mkdir(parents=True, exist_ok=True)
        return path
