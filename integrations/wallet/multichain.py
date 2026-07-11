from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal
import os
from typing import Any, Dict, Iterable, Optional

import requests

from ..etherscan import EtherscanAPIError, EtherscanV2Client


class WalletChainError(RuntimeError):
    pass


@dataclass(frozen=True)
class NetworkSpec:
    id: str
    family: str
    name: str
    symbol: str
    chain_id: Optional[int] = None
    rpc_env: Optional[str] = None
    default_rpc_url: Optional[str] = None
    explorer: Optional[str] = None
    decimals: int = 18

    def to_dict(self) -> Dict[str, Any]:
        return {
            "id": self.id,
            "family": self.family,
            "name": self.name,
            "symbol": self.symbol,
            "chain_id": self.chain_id,
            "rpc_env": self.rpc_env,
            "explorer": self.explorer,
            "decimals": self.decimals,
        }


NETWORKS: tuple[NetworkSpec, ...] = (
    NetworkSpec("ethereum", "evm", "Ethereum", "ETH", chain_id=1, rpc_env="ETHEREUM_RPC_URL", explorer="etherscan"),
    NetworkSpec("base", "evm", "Base", "ETH", chain_id=8453, rpc_env="BASE_RPC_URL", explorer="etherscan"),
    NetworkSpec("arbitrum", "evm", "Arbitrum One", "ETH", chain_id=42161, rpc_env="ARBITRUM_RPC_URL", explorer="etherscan"),
    NetworkSpec("optimism", "evm", "Optimism", "ETH", chain_id=10, rpc_env="OPTIMISM_RPC_URL", explorer="etherscan"),
    NetworkSpec("polygon", "evm", "Polygon", "MATIC", chain_id=137, rpc_env="POLYGON_RPC_URL", explorer="etherscan"),
    NetworkSpec("bsc", "evm", "BNB Smart Chain", "BNB", chain_id=56, rpc_env="BSC_RPC_URL", explorer="etherscan"),
    NetworkSpec("avalanche", "evm", "Avalanche C-Chain", "AVAX", chain_id=43114, rpc_env="AVALANCHE_RPC_URL", explorer="etherscan"),
    NetworkSpec("linea", "evm", "Linea", "ETH", chain_id=59144, rpc_env="LINEA_RPC_URL", explorer="etherscan"),
    NetworkSpec("blast", "evm", "Blast", "ETH", chain_id=81457, rpc_env="BLAST_RPC_URL", explorer="etherscan"),
    NetworkSpec("scroll", "evm", "Scroll", "ETH", chain_id=534352, rpc_env="SCROLL_RPC_URL", explorer="etherscan"),
    NetworkSpec("zksync", "evm", "zkSync Era", "ETH", chain_id=324, rpc_env="ZKSYNC_RPC_URL", explorer="etherscan"),
    NetworkSpec(
        "tron",
        "tron",
        "TRON Mainnet",
        "TRX",
        rpc_env="TRON_API_URL",
        default_rpc_url="https://api.trongrid.io",
        decimals=6,
    ),
    NetworkSpec(
        "solana",
        "solana",
        "Solana Mainnet",
        "SOL",
        rpc_env="SOLANA_RPC_URL",
        default_rpc_url="https://api.mainnet-beta.solana.com",
        decimals=9,
    ),
    NetworkSpec(
        "bitcoin",
        "bitcoin",
        "Bitcoin Mainnet",
        "BTC",
        rpc_env="BITCOIN_API_URL",
        default_rpc_url="https://blockstream.info/api",
        decimals=8,
    ),
)

NETWORK_BY_ID = {network.id: network for network in NETWORKS}
NETWORK_ALIASES = {
    "1": "ethereum",
    "eth": "ethereum",
    "8453": "base",
    "arb": "arbitrum",
    "42161": "arbitrum",
    "op": "optimism",
    "10": "optimism",
    "matic": "polygon",
    "137": "polygon",
    "binance-smart-chain": "bsc",
    "bnb": "bsc",
    "56": "bsc",
    "avax": "avalanche",
    "43114": "avalanche",
    "59144": "linea",
    "81457": "blast",
    "534352": "scroll",
    "324": "zksync",
    "trc20": "tron",
    "trx": "tron",
    "sol": "solana",
    "btc": "bitcoin",
}


class MultiChainWalletService:
    def __init__(self, *, session: Optional[requests.Session] = None, timeout: float = 20.0):
        self.session = session or requests.Session()
        self.timeout = timeout

    def list_networks(self, family: Optional[str] = None) -> list[Dict[str, Any]]:
        networks = NETWORKS
        if family:
            needle = family.strip().lower()
            networks = tuple(network for network in networks if network.family == needle)
        return [network.to_dict() for network in networks]

    def resolve_network(self, network: str) -> NetworkSpec:
        key = (network or "").strip().lower()
        if not key:
            raise WalletChainError("network required")
        resolved = NETWORK_ALIASES.get(key, key)
        if resolved not in NETWORK_BY_ID:
            raise WalletChainError(f"unsupported network: {network}")
        return NETWORK_BY_ID[resolved]

    def get_balance(self, *, network: str, address: str) -> Dict[str, Any]:
        spec = self.resolve_network(network)
        if spec.family == "evm":
            return self._evm_balance(spec, address)
        if spec.family == "tron":
            return self._tron_balance(spec, address)
        if spec.family == "solana":
            return self._solana_balance(spec, address)
        if spec.family == "bitcoin":
            return self._bitcoin_balance(spec, address)
        raise WalletChainError(f"unsupported network family: {spec.family}")

    def get_token_balance(self, *, network: str, address: str, token_address: str) -> Dict[str, Any]:
        spec = self.resolve_network(network)
        if spec.family == "evm":
            return self._evm_token_balance(spec, address, token_address)
        if spec.family == "tron":
            return self._tron_token_balance(spec, address, token_address)
        if spec.family == "solana":
            return self._solana_token_balance(spec, address, token_address)
        raise WalletChainError(f"token balances are not supported for network: {spec.id}")

    def broadcast(
        self,
        *,
        network: str,
        raw_transaction: Optional[str] = None,
        payload: Optional[Dict[str, Any]] = None,
        encoding: Optional[str] = None,
    ) -> Dict[str, Any]:
        spec = self.resolve_network(network)
        if spec.family == "evm":
            if not raw_transaction:
                raise WalletChainError("raw_transaction required for EVM broadcast")
            result = self._evm_rpc(
                spec,
                method="eth_sendRawTransaction",
                params=[self._ensure_0x(raw_transaction)],
            )
            return {"network": spec.id, "family": spec.family, "tx_hash": result}
        if spec.family == "tron":
            return self._tron_broadcast(spec, raw_transaction=raw_transaction, payload=payload)
        if spec.family == "solana":
            if not raw_transaction:
                raise WalletChainError("raw_transaction required for Solana broadcast")
            result = self._solana_rpc(
                spec,
                method="sendTransaction",
                params=[raw_transaction, {"encoding": encoding or "base64"}],
            )
            return {"network": spec.id, "family": spec.family, "signature": result}
        if spec.family == "bitcoin":
            if not raw_transaction:
                raise WalletChainError("raw_transaction required for Bitcoin broadcast")
            return self._bitcoin_broadcast(spec, raw_transaction)
        raise WalletChainError(f"unsupported network family: {spec.family}")

    def build_portfolio(
        self,
        *,
        addresses: Dict[str, str],
        networks: Optional[Iterable[str]] = None,
    ) -> Dict[str, Any]:
        requested = list(networks or [network.id for network in NETWORKS])
        results: list[Dict[str, Any]] = []
        ok = True
        for network in requested:
            spec = self.resolve_network(network)
            address = self._pick_address_for_network(addresses, spec)
            if not address:
                results.append(
                    {
                        "network": spec.id,
                        "family": spec.family,
                        "ok": False,
                        "error": "missing_address",
                    }
                )
                ok = False
                continue
            try:
                balance = self.get_balance(network=spec.id, address=address)
                results.append({"network": spec.id, "family": spec.family, "ok": True, "balance": balance})
            except Exception as exc:  # pragma: no cover - defensive aggregation
                results.append(
                    {
                        "network": spec.id,
                        "family": spec.family,
                        "ok": False,
                        "error": str(exc),
                    }
                )
                ok = False
        return {"ok": ok, "results": results}

    def _pick_address_for_network(self, addresses: Dict[str, str], spec: NetworkSpec) -> Optional[str]:
        candidates = [
            addresses.get(spec.id),
            addresses.get(spec.family),
            addresses.get("evm") if spec.family == "evm" else None,
            addresses.get("default"),
            addresses.get("address"),
        ]
        return next((value for value in candidates if value), None)

    def _etherscan_client(self, spec: NetworkSpec) -> EtherscanV2Client:
        return EtherscanV2Client(
            base_url=os.getenv("ETHERSCAN_API_URL", "https://api.etherscan.io/api"),
            chain_id=spec.chain_id,
            session=self.session,
            timeout=self.timeout,
        )

    def _rpc_url(self, spec: NetworkSpec) -> str:
        if spec.rpc_env and os.getenv(spec.rpc_env):
            return os.environ[spec.rpc_env]
        if spec.default_rpc_url:
            return spec.default_rpc_url
        raise WalletChainError(f"missing RPC URL for network {spec.id}; expected env {spec.rpc_env}")

    def _rpc_json(self, url: str, payload: Dict[str, Any]) -> Any:
        try:
            response = self.session.post(url, json=payload, timeout=self.timeout)
            response.raise_for_status()
            data = response.json()
        except requests.RequestException as exc:
            raise WalletChainError(f"network error: {exc.__class__.__name__}: {exc}") from exc
        except ValueError as exc:
            raise WalletChainError("invalid JSON response from upstream") from exc
        if isinstance(data, dict) and data.get("error"):
            raise WalletChainError(f"upstream RPC error: {data['error']}")
        return data.get("result") if isinstance(data, dict) else data

    def _evm_rpc(self, spec: NetworkSpec, *, method: str, params: list[Any]) -> Any:
        payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
        return self._rpc_json(self._rpc_url(spec), payload)

    def _solana_rpc(self, spec: NetworkSpec, *, method: str, params: list[Any]) -> Any:
        payload = {"jsonrpc": "2.0", "id": 1, "method": method, "params": params}
        return self._rpc_json(self._rpc_url(spec), payload)

    def _evm_balance(self, spec: NetworkSpec, address: str) -> Dict[str, Any]:
        wei: int
        try:
            result = self._evm_rpc(spec, method="eth_getBalance", params=[address, "latest"])
            wei = int(result, 16)
        except WalletChainError:
            try:
                wei = self._etherscan_client(spec).get_eth_balance(address)
            except (EtherscanAPIError, ValueError) as exc:
                raise WalletChainError(str(exc)) from exc
        return {
            "network": spec.id,
            "family": spec.family,
            "symbol": spec.symbol,
            "address": address,
            "balance_wei": str(wei),
            "balance": self._format_amount(wei, spec.decimals),
        }

    def _evm_token_balance(self, spec: NetworkSpec, address: str, token_address: str) -> Dict[str, Any]:
        raw_value: int
        try:
            data = self._erc20_balance_of_call(address)
            result = self._evm_rpc(
                spec,
                method="eth_call",
                params=[{"to": token_address, "data": data}, "latest"],
            )
            raw_value = int(result, 16)
        except WalletChainError:
            try:
                raw_value = self._etherscan_client(spec).get_token_balance(address=address, contract_address=token_address)
            except (EtherscanAPIError, ValueError) as exc:
                raise WalletChainError(str(exc)) from exc
        return {
            "network": spec.id,
            "family": spec.family,
            "address": address,
            "token_address": token_address,
            "balance_raw": str(raw_value),
        }

    def _tron_balance(self, spec: NetworkSpec, address: str) -> Dict[str, Any]:
        url = self._rpc_url(spec).rstrip("/") + f"/v1/accounts/{address}"
        try:
            response = self.session.get(url, timeout=self.timeout)
            response.raise_for_status()
            data = response.json()
        except requests.RequestException as exc:
            raise WalletChainError(f"TRON balance request failed: {exc}") from exc
        account = ((data or {}).get("data") or [{}])[0]
        sun = int(account.get("balance", 0))
        return {
            "network": spec.id,
            "family": spec.family,
            "symbol": spec.symbol,
            "address": address,
            "balance_sun": str(sun),
            "balance": self._format_amount(sun, spec.decimals),
        }

    def _tron_token_balance(self, spec: NetworkSpec, address: str, token_address: str) -> Dict[str, Any]:
        url = self._rpc_url(spec).rstrip("/") + f"/v1/accounts/{address}"
        try:
            response = self.session.get(url, timeout=self.timeout)
            response.raise_for_status()
            data = response.json()
        except requests.RequestException as exc:
            raise WalletChainError(f"TRON token balance request failed: {exc}") from exc
        account = ((data or {}).get("data") or [{}])[0]
        balances = account.get("trc20") or []
        token_key = token_address.lower()
        raw_value = "0"
        for item in balances:
            if not isinstance(item, dict):
                continue
            for contract, amount in item.items():
                if contract.lower() == token_key:
                    raw_value = str(amount)
                    break
        return {
            "network": spec.id,
            "family": spec.family,
            "address": address,
            "token_address": token_address,
            "balance_raw": raw_value,
        }

    def _tron_broadcast(
        self,
        spec: NetworkSpec,
        *,
        raw_transaction: Optional[str],
        payload: Optional[Dict[str, Any]],
    ) -> Dict[str, Any]:
        url = self._rpc_url(spec).rstrip("/") + "/wallet/broadcasttransaction"
        body: Any = payload if payload is not None else {"raw_transaction": raw_transaction}
        try:
            response = self.session.post(url, json=body, timeout=self.timeout)
            response.raise_for_status()
            data = response.json()
        except requests.RequestException as exc:
            raise WalletChainError(f"TRON broadcast failed: {exc}") from exc
        return {"network": spec.id, "family": spec.family, "result": data}

    def _solana_balance(self, spec: NetworkSpec, address: str) -> Dict[str, Any]:
        result = self._solana_rpc(spec, method="getBalance", params=[address])
        lamports = int((result or {}).get("value", 0))
        return {
            "network": spec.id,
            "family": spec.family,
            "symbol": spec.symbol,
            "address": address,
            "balance_lamports": str(lamports),
            "balance": self._format_amount(lamports, spec.decimals),
        }

    def _solana_token_balance(self, spec: NetworkSpec, address: str, token_address: str) -> Dict[str, Any]:
        result = self._solana_rpc(
            spec,
            method="getTokenAccountsByOwner",
            params=[address, {"mint": token_address}, {"encoding": "jsonParsed"}],
        )
        accounts = (result or {}).get("value", [])
        total = 0
        for entry in accounts:
            parsed = (((entry or {}).get("account") or {}).get("data") or {}).get("parsed") or {}
            info = parsed.get("info") or {}
            amount = ((info.get("tokenAmount") or {}).get("amount")) or "0"
            total += int(amount)
        return {
            "network": spec.id,
            "family": spec.family,
            "address": address,
            "token_address": token_address,
            "balance_raw": str(total),
        }

    def _bitcoin_balance(self, spec: NetworkSpec, address: str) -> Dict[str, Any]:
        url = self._rpc_url(spec).rstrip("/") + f"/address/{address}"
        try:
            response = self.session.get(url, timeout=self.timeout)
            response.raise_for_status()
            data = response.json()
        except requests.RequestException as exc:
            raise WalletChainError(f"Bitcoin balance request failed: {exc}") from exc
        chain = data.get("chain_stats") or {}
        mempool = data.get("mempool_stats") or {}
        sats = int(chain.get("funded_txo_sum", 0)) - int(chain.get("spent_txo_sum", 0))
        sats += int(mempool.get("funded_txo_sum", 0)) - int(mempool.get("spent_txo_sum", 0))
        return {
            "network": spec.id,
            "family": spec.family,
            "symbol": spec.symbol,
            "address": address,
            "balance_sats": str(sats),
            "balance": self._format_amount(sats, spec.decimals),
        }

    def _bitcoin_broadcast(self, spec: NetworkSpec, raw_transaction: str) -> Dict[str, Any]:
        url = self._rpc_url(spec).rstrip("/") + "/tx"
        try:
            response = self.session.post(
                url,
                data=raw_transaction,
                headers={"Content-Type": "text/plain"},
                timeout=self.timeout,
            )
            response.raise_for_status()
        except requests.RequestException as exc:
            raise WalletChainError(f"Bitcoin broadcast failed: {exc}") from exc
        tx_hash = response.text.strip().strip('"')
        return {"network": spec.id, "family": spec.family, "tx_hash": tx_hash}

    def _erc20_balance_of_call(self, address: str) -> str:
        clean = address.lower().removeprefix("0x")
        if len(clean) != 40:
            raise WalletChainError("invalid EVM address for balanceOf call")
        return "0x70a08231" + clean.rjust(64, "0")

    def _ensure_0x(self, raw_transaction: str) -> str:
        raw = raw_transaction.strip()
        if raw.startswith("0x"):
            return raw
        return "0x" + raw

    def _format_amount(self, raw: int, decimals: int) -> str:
        quantized = Decimal(raw) / (Decimal(10) ** decimals)
        return format(quantized.normalize(), "f")
