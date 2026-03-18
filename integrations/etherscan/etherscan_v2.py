"""Minimal Etherscan v2 client with graceful fallback to legacy endpoints.

Focus:
- Token holder enumeration (attempt v2, fallback to legacy tokentx synthesis)
- Basic ERC20 transfer + balance helpers
- Contract verification passthrough (legacy)

This file intentionally keeps a narrow surface to avoid prior heredoc duplication issues.
"""

from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple
import copy
import os
import time
import requests
from ..cache import cache_get_value, cache_set

__all__ = ["EtherscanV2Client", "EtherscanAPIError", "EtherscanV2Error"]


class EtherscanAPIError(RuntimeError):
    """Domain error raised when the remote API signals NOTOK / failure."""
    def __init__(self, message: str, payload: Optional[Dict[str, Any]] = None):
        self.payload = payload or {}
        super().__init__(message)


EtherscanV2Error = EtherscanAPIError


def _normalize_v2_base(url: str) -> str:
    url = url.rstrip("/")
    if url.endswith("/v2/api"):
        return url
    if url.endswith("/v2"):
        return url + "/api"
    if url.endswith("/api"):
        # user supplied legacy base; upgrade path
        return url[:-4] + "v2/api"
    return url + "/v2/api"


def _normalize_legacy_base(url: str) -> str:
    url = url.rstrip("/")
    if url.endswith("/api"):
        return url
    return url + "/api"


def _clean_addr(addr: str) -> str:
    return addr.strip().lower()


def _is_api_error(data: Dict[str, Any]) -> bool:
    status = str(data.get("status", ""))
    message = str(data.get("message", "")).upper()
    return status == "0" or message.startswith("NOTOK")


class EtherscanV2Client:
    DEFAULT_BASE = "https://api.etherscan.io"

    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: str = DEFAULT_BASE,
        *,
        session: Optional[requests.Session] = None,
        chain_id: Optional[int] = None,
        timeout: float = 15.0,
    ):
        self.api_key = api_key or os.getenv("ETHERSCAN_API_KEY") or ""
        if not self.api_key:
            raise ValueError("Missing Etherscan API key (env ETHERSCAN_API_KEY).")
        self.base_v2 = _normalize_v2_base(base_url)
        self.base_legacy = _normalize_legacy_base(base_url)
        self.session = session or requests.Session()
        self.chain_id = chain_id or self._infer_chain_id_from_env()
        self.timeout = timeout

    # -------- internal helpers --------
    def _infer_chain_id_from_env(self) -> Optional[int]:
        raw = os.getenv("CHAIN_ID") or os.getenv("ETH_CHAIN_ID")
        if not raw:
            return None
        try:
            return int(raw, 0)
        except ValueError:
            return None

    def _raise_for_api_error(self, data: Dict[str, Any]) -> None:
        if _is_api_error(data):
            raise EtherscanAPIError(
                f"API error: {data.get('message')} (result={data.get('result')})",
                payload=data,
            )

    def _cache_disabled(self) -> bool:
        return os.getenv("DISABLE_CACHE", "").lower() in ("1", "true", "yes", "on")

    def _cache_ttl(self) -> int:
        try:
            return int(os.getenv("ETHERSCAN_CACHE_TTL", "60") or "60")
        except ValueError:
            return 60

    def _cache_key(
        self,
        *,
        action: str,
        contractaddress: str,
        page: Optional[int] = None,
        offset: Optional[int] = None,
    ) -> str:
        return ":".join(
            [
                "etherscan",
                "v2",
                action,
                self.base_v2,
                str(self.chain_id or ""),
                contractaddress,
                str(page or ""),
                str(offset or ""),
            ]
        )

    def _get_cached_response(self, key: str) -> Optional[Dict[str, Any]]:
        if self._cache_disabled():
            return None
        cached = cache_get_value(key)
        if not isinstance(cached, dict):
            return None
        payload = copy.deepcopy(cached)
        payload["cached"] = True
        return payload

    def _cache_response(self, key: str, data: Dict[str, Any]) -> None:
        if self._cache_disabled():
            return
        cache_set(key, data, self._cache_ttl())

    def _perform_request(self, base: str, params: Dict[str, Any]) -> Dict[str, Any]:
        p = dict(params)
        p["apikey"] = self.api_key
        try:
            resp = self.session.get(base, params=p, timeout=self.timeout)
            resp.raise_for_status()
        except requests.RequestException as e:
            raise EtherscanAPIError(f"Network error: {e.__class__.__name__}: {e}") from e
        try:
            data = resp.json()
        except ValueError as e:
            raise EtherscanAPIError("Invalid JSON response", {"text": resp.text[:200]}) from e

        self._raise_for_api_error(data)
        return data

    def _request(self, params: Dict[str, Any]) -> Dict[str, Any]:
        p = dict(params)
        if self.chain_id is not None:
            p.setdefault("chainid", self.chain_id)
        return self._perform_request(self.base_v2, p)

    def _request_legacy(self, params: Dict[str, Any]) -> Dict[str, Any]:
        return self._perform_request(self.base_legacy, params)

    def _v2(self, params: Dict[str, Any]) -> Dict[str, Any]:
        return self._request(params)

    def _legacy(self, params: Dict[str, Any]) -> Dict[str, Any]:
        return self._request_legacy(params)

    def _request_with_module_fallback(
        self,
        *,
        action: str,
        contractaddress: str,
        page: Optional[int] = None,
        offset: Optional[int] = None,
        modules: Tuple[str, str] = ("tokens", "token"),
    ) -> Dict[str, Any]:
        last_error: Optional[EtherscanAPIError] = None
        for module_name in modules:
            params: Dict[str, Any] = {
                "module": module_name,
                "action": action,
                "contractaddress": contractaddress,
            }
            if page is not None:
                params["page"] = page
            if offset is not None:
                params["offset"] = offset
            try:
                data = self._request(params)
                self._raise_for_api_error(data)
                return data
            except EtherscanAPIError as exc:
                last_error = exc

        raise EtherscanAPIError(
            f"{action} failed after module fallback",
            payload=getattr(last_error, "payload", {}),
        ) from last_error

    # -------- public endpoints --------
    def get_eth_balance(self, address: str) -> int:
        address = _clean_addr(address)
        data = self._legacy(
            {
                "module": "account",
                "action": "balance",
                "address": address,
                "tag": "latest",
            }
        )
        result = data.get("result")
        try:
            return int(result)
        except (TypeError, ValueError):
            raise EtherscanAPIError("Unexpected balance format", data)

    def get_token_balance(self, address: str, contract_address: str) -> int:
        address = _clean_addr(address)
        contract_address = _clean_addr(contract_address)
        data = self._legacy(
            {
                "module": "account",
                "action": "tokenbalance",
                "address": address,
                "contractaddress": contract_address,
                "tag": "latest",
            }
        )
        result = data.get("result")
        try:
            return int(result)
        except (TypeError, ValueError):
            raise EtherscanAPIError("Unexpected token balance format", data)

    def get_erc20_transfers(
        self,
        address: str,
        contract_address: Optional[str] = None,
        page: int = 1,
        offset: int = 100,
        sort: str = "desc",
    ) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
        address = _clean_addr(address)
        params = {
            "module": "account",
            "action": "tokentx",
            "address": address,
            "page": page,
            "offset": offset,
            "sort": sort,
        }
        if contract_address:
            params["contractaddress"] = _clean_addr(contract_address)
        data = self._legacy(params)
        result = data.get("result") or []
        if not isinstance(result, list):
            raise EtherscanAPIError("Unexpected tokentx shape", data)
        return result, data

    def _token_transfer_query(
        self,
        *,
        action: str,
        address: str,
        page: int = 1,
        offset: int = 100,
        sort: str = "desc",
        contractaddress: Optional[str] = None,
        startblock: int = 0,
        endblock: int = 99999999,
    ) -> Dict[str, Any]:
        params: Dict[str, Any] = {
            "module": "account",
            "action": action,
            "address": _clean_addr(address),
            "page": page,
            "offset": offset,
            "sort": sort,
            "startblock": startblock,
            "endblock": endblock,
        }
        if contractaddress:
            params["contractaddress"] = _clean_addr(contractaddress)
        return self._legacy(params)

    def erc20_transfers(
        self,
        address: str,
        page: int = 1,
        offset: int = 100,
        sort: str = "desc",
        contractaddress: Optional[str] = None,
        startblock: int = 0,
        endblock: int = 99999999,
    ) -> Dict[str, Any]:
        return self._token_transfer_query(
            action="tokentx",
            address=address,
            page=page,
            offset=offset,
            sort=sort,
            contractaddress=contractaddress,
            startblock=startblock,
            endblock=endblock,
        )

    def erc721_transfers(
        self,
        address: str,
        page: int = 1,
        offset: int = 100,
        sort: str = "desc",
        contractaddress: Optional[str] = None,
        startblock: int = 0,
        endblock: int = 99999999,
    ) -> Dict[str, Any]:
        return self._token_transfer_query(
            action="tokennfttx",
            address=address,
            page=page,
            offset=offset,
            sort=sort,
            contractaddress=contractaddress,
            startblock=startblock,
            endblock=endblock,
        )

    def erc1155_transfers(
        self,
        address: str,
        page: int = 1,
        offset: int = 100,
        sort: str = "desc",
        contractaddress: Optional[str] = None,
        startblock: int = 0,
        endblock: int = 99999999,
    ) -> Dict[str, Any]:
        return self._token_transfer_query(
            action="token1155tx",
            address=address,
            page=page,
            offset=offset,
            sort=sort,
            contractaddress=contractaddress,
            startblock=startblock,
            endblock=endblock,
        )

    def tokenholder_list(
        self,
        contractaddress: str,
        page: int = 1,
        offset: int = 100,
    ) -> Dict[str, Any]:
        contractaddress = _clean_addr(contractaddress)
        cache_key = self._cache_key(
            action="tokenholderlist",
            contractaddress=contractaddress,
            page=page,
            offset=offset,
        )
        cached = self._get_cached_response(cache_key)
        if cached is not None:
            return cached
        data = self._request_with_module_fallback(
            action="tokenholderlist",
            contractaddress=contractaddress,
            page=page,
            offset=offset,
        )
        self._cache_response(cache_key, data)
        return data

    def tokenholder_count(self, contractaddress: str) -> Dict[str, Any]:
        contractaddress = _clean_addr(contractaddress)
        cache_key = self._cache_key(
            action="tokenholdercount",
            contractaddress=contractaddress,
        )
        cached = self._get_cached_response(cache_key)
        if cached is not None:
            return cached
        data = self._request_with_module_fallback(
            action="tokenholdercount",
            contractaddress=contractaddress,
        )
        self._cache_response(cache_key, data)
        return data

    def get_token_holders(
        self,
        contract_address: str,
        page: int = 1,
        offset: int = 100,
        sort: str = "desc",
        *,
        synth_limit: int = 500,
    ) -> Dict[str, Any]:
        """Return token holder list.

        Strategy:
        1. Try v2 with a module fallback (`tokens` -> `token`)
        2. On failure, fallback: derive distinct 'to' addresses from tokentx
        """
        contract_address = _clean_addr(contract_address)
        try:
            data = self.tokenholder_list(
                contractaddress=contract_address,
                page=page,
                offset=offset,
            )
            holders = data.get("result") or []
            if not isinstance(holders, list):
                raise EtherscanAPIError("Unexpected holder list shape", data)
            return {
                "holders": holders,
                "count": len(holders),
                "source": "v2",
                "raw": data,
                "cached": bool(data.get("cached")),
            }
        except EtherscanAPIError as v2_err:
            # Fallback via synthesized transfer scan
            try:
                transfers, raw = self.get_erc20_transfers(
                    address=contract_address,  # Not strictly correct but ensures some coverage
                    contract_address=contract_address,
                    page=1,
                    offset=min(synth_limit, offset),
                    sort="desc",
                )
            except EtherscanAPIError as legacy_err:
                raise EtherscanAPIError(
                    f"Both v2 and legacy synthesis failed: v2={v2_err} legacy={legacy_err}"
                ) from legacy_err

            holder_set = []
            seen = set()
            for tx in transfers:
                to_addr = _clean_addr(tx.get("to", "")) if isinstance(tx, dict) else ""
                if to_addr.startswith("0x") and to_addr not in seen:
                    seen.add(to_addr)
                    holder_set.append({"address": to_addr})
                if len(holder_set) >= offset:
                    break

            return {
                "holders": holder_set,
                "count": len(holder_set),
                "source": "fallback_tokentx",
                "raw": {"v2_error": str(v2_err)},
            }

    def verify_contract(
        self,
        source_code: str,
        contract_name: str,
        compiler_version: str,
        optimization_used: int = 1,
        constructor_arguments: str = "",
        evm_version: str = "",
        license_type: int = 1,
        **extra_fields: Any,
    ) -> Dict[str, Any]:
        """Submit a contract verification (legacy endpoint)."""
        payload = {
            "module": "contract",
            "action": "verifysourcecode",
            "sourceCode": source_code,
            "contractname": contract_name,
            "compilerversion": compiler_version,
            "optimizationUsed": optimization_used,
            "runs": 200,
            "constructorArguements": constructor_arguments,  # Etherscan historical typo
            "evmversion": evm_version,
            "licenseType": license_type,
        }
        payload.update(extra_fields)
        # Use POST for verification
        p = dict(payload)
        p["apikey"] = self.api_key
        try:
            resp = self.session.post(self.base_legacy, data=p, timeout=self.timeout)
            resp.raise_for_status()
            data = resp.json()
        except requests.RequestException as e:
            raise EtherscanAPIError(f"Network error: {e}") from e
        except ValueError as e:
            raise EtherscanAPIError("Invalid JSON in verification response") from e

        status = str(data.get("status", ""))
        message = str(data.get("message", "")).upper()
        if status == "0" or message.startswith("NOTOK"):
            raise EtherscanAPIError(f"Verification failed: {data.get('message')}", data)
        return data


# -------- simple CLI test --------
def _demo():
    key_present = bool(os.getenv("ETHERSCAN_API_KEY"))
    print(f"[demo] API key present: {key_present}")
    if not key_present:
        print("Set ETHERSCAN_API_KEY to run demo.")
        return
    client = EtherscanV2Client()
    # Choose a stable contract (USDC)
    usdc = "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48"
    try:
        holders = client.get_token_holders(usdc, offset=5)
        print("Holders sample:", holders["holders"])
    except Exception as e:
        print("Holder fetch error:", e)

    try:
        bal = client.get_eth_balance("0x0000000000000000000000000000000000000000")
        print("Zero address balance (wei):", bal)
    except Exception as e:
        print("Balance error:", e)

    try:
        transfers, _ = client.get_erc20_transfers(usdc, contract_address=usdc, offset=2)
        print("Transfers sample len:", len(transfers))
    except Exception as e:
        print("Transfers error:", e)


if __name__ == "__main__":
    start = time.time()
    _demo()
    print(f"Done in {time.time() - start:.2f} seconds.")
