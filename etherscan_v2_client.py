#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from __future__ import annotations
import os, asyncio, random
from typing import Any, Dict, List, Optional, Tuple
import aiohttp
from aiohttp import ClientResponseError
from dotenv import load_dotenv

load_dotenv(override=False)

API_KEY: str = os.getenv("ETHERSCAN_API_KEY", "")
DEFAULT_CHAIN: int = int(os.getenv("DEFAULT_CHAINID", "1"))
BASE_URL: str = "https://api.etherscan.io/v2/api"

SUPPORTED_CHAINS: Tuple[int, ...] = (1, 42161, 8453, 10, 56, 43114)

class EtherscanV2Client:
    def __init__(
        self,
        api_key: Optional[str] = None,
        chain_id: int = DEFAULT_CHAIN,
        session: Optional[aiohttp.ClientSession] = None,
        max_retries: int = 3,
        timeout: int = 15,
    ) -> None:
        if chain_id not in SUPPORTED_CHAINS:
            raise ValueError(f"Unsupported chainId={chain_id}")
        self.chain_id = chain_id
        self.api_key = api_key if api_key is not None else API_KEY  # env fallback
        self.base_params = {"chainid": chain_id}
        if self.api_key:
            self.base_params["apikey"] = self.api_key
        self.max_retries = max_retries
        self._session_provided = session is not None
        self.session = session or aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=timeout),
                                                        headers={"User-Agent": "qai/etherscan-v2"})
    async def _get(self, **params: Any) -> Dict[str, Any]:
        merged = {**self.base_params, **params}
        # Bazı endpointler API key şart koşar
        needs_key = params.get("module") in ("stats", "account", "contract", "transaction")
        if needs_key and not self.api_key:
            raise RuntimeError("ETHERSCAN_API_KEY not set (required for this endpoint)")

        for attempt in range(1, self.max_retries + 1):
            try:
                async with self.session.get(BASE_URL, params=merged) as resp:
                    # 429/5xx için özel ele alma
                    if resp.status in (429, 500, 502, 503, 504):
                        raise ClientResponseError(resp.request_info, resp.history,
                                                  status=resp.status, message=f"http {resp.status}")
                    resp.raise_for_status()
                    data = await resp.json()
                    if data.get("status") not in ("1", 1):
                        # Bazı hatalarda status "0" + message/result gelir
                        raise ValueError(f"API error: {data.get('message')} ({data.get('result')})")
                    return data
            except (ClientResponseError, ValueError) as e:
                if attempt == self.max_retries:
                    raise
                # Exponential backoff + jitter
                delay = (1.25 ** attempt) + random.uniform(0.05, 0.25)
                await asyncio.sleep(delay)
        raise RuntimeError("retry-exhausted")

    async def get_eth_balance(self, address: str) -> int:
        data = await self._get(module="account", action="balance", address=address, tag="latest")
        return int(data["result"])

    async def get_eth_balance_multi(self, addresses: List[str]) -> Dict[str, int]:
        joined = ",".join(addresses[:20])
        data = await self._get(module="account", action="balancemulti", address=joined, tag="latest")
        return {item["account"]: int(item["balance"]) for item in data["result"]}

    async def tx_list(self, address: str, start_block: int = 0, end_block: int = 9_999_999_9,
                      page: int = 1, offset: int = 10, sort: str = "asc"):
        return (await self._get(module="account", action="txlist", address=address,
                                startblock=start_block, endblock=end_block,
                                page=page, offset=offset, sort=sort))["result"]

    async def get_eth_price(self) -> float:
        data = await self._get(module="stats", action="ethprice", chainid=1)
        result = data.get("result") or {}
        return float(result.get("ethusd", 0.0))

    async def close(self) -> None:
        if not self._session_provided and not self.session.closed:
            await self.session.close()

    async def __aenter__(self) -> "EtherscanV2Client":
        return self

    async def __aexit__(self, exc_type, exc, tb) -> None:
        await self.close()

if __name__ == "__main__":
    async def demo() -> None:
        addr = "0xb5d85cbf7cb3ee0d56b3bb207d5fc4b82f43f511"
        for cid in (42161, 8453, 10):
            async with EtherscanV2Client(chain_id=cid) as cli:
                bal = await cli.get_eth_balance(addr)
                print(f"[chain {cid}] balance = {bal:,} wei")
    asyncio.run(demo())