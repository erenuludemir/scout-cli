from __future__ import annotations

from typing import Any, Dict, Optional

from .etherscan_v2 import EtherscanAPIError, EtherscanV2Client, EtherscanV2Error


class EtherscanClient(EtherscanV2Client):
    """Compatibility wrapper preserving the historical client import path."""

    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: str = EtherscanV2Client.DEFAULT_BASE,
        *,
        session=None,
        chain_id: Optional[int] = None,
        chainid: Optional[int] = None,
        timeout: float = 15.0,
    ):
        super().__init__(
            api_key=api_key,
            base_url=base_url,
            session=session,
            chain_id=chain_id if chain_id is not None else chainid,
            timeout=timeout,
        )

    def get_balance_wei(self, address: str) -> int:
        return self.get_eth_balance(address)

    def get_txlist(
        self,
        address: str,
        start_block: int = 0,
        end_block: int = 99999999,
        page: int = 1,
        offset: int = 100,
        sort: str = "asc",
    ) -> list[Dict[str, Any]]:
        data = self._legacy(
            {
                "module": "account",
                "action": "txlist",
                "address": address.strip().lower(),
                "startblock": start_block,
                "endblock": end_block,
                "page": page,
                "offset": offset,
                "sort": sort,
            }
        )
        result = data.get("result") or []
        if not isinstance(result, list):
            raise EtherscanAPIError("Unexpected txlist shape", data)
        return result

    def token_info(self, contractaddress: str) -> Dict[str, Any]:
        return self._request_with_module_fallback(
            action="tokeninfo",
            contractaddress=contractaddress.strip().lower(),
        )

    def address_token_balance(
        self,
        address: str,
        contractaddress: str,
        tag: str = "latest",
    ) -> int:
        _ = tag  # legacy signature compatibility
        return self.get_token_balance(address=address, contract_address=contractaddress)

    def erc721_inventory(
        self,
        address: str,
        contractaddress: str,
        page: int = 1,
        offset: int = 50,
    ) -> Dict[str, Any]:
        return self._request(
            {
                "module": "account",
                "action": "erc721inventory",
                "address": address.strip().lower(),
                "contractaddress": contractaddress.strip().lower(),
                "page": page,
                "offset": offset,
            }
        )

    def erc1155_inventory(
        self,
        address: str,
        contractaddress: str,
        page: int = 1,
        offset: int = 50,
    ) -> Dict[str, Any]:
        return self._request(
            {
                "module": "account",
                "action": "erc1155inventory",
                "address": address.strip().lower(),
                "contractaddress": contractaddress.strip().lower(),
                "page": page,
                "offset": offset,
            }
        )

    def get_logs(
        self,
        address: str,
        from_block: int,
        to_block: int,
        *,
        topic0: Optional[str] = None,
        topic1: Optional[str] = None,
        topic2: Optional[str] = None,
        topic3: Optional[str] = None,
        topic0_1_opr: Optional[str] = None,
        topic1_2_opr: Optional[str] = None,
        topic2_3_opr: Optional[str] = None,
        page: int = 1,
        offset: int = 1000,
    ) -> list[Dict[str, Any]]:
        params: Dict[str, Any] = {
            "module": "logs",
            "action": "getLogs",
            "address": address.strip().lower(),
            "fromBlock": from_block,
            "toBlock": to_block,
            "page": page,
            "offset": offset,
        }
        for key, value in {
            "topic0": topic0,
            "topic1": topic1,
            "topic2": topic2,
            "topic3": topic3,
            "topic0_1_opr": topic0_1_opr,
            "topic1_2_opr": topic1_2_opr,
            "topic2_3_opr": topic2_3_opr,
        }.items():
            if value:
                params[key] = value
        data = self._legacy(params)
        result = data.get("result") or []
        if not isinstance(result, list):
            raise EtherscanAPIError("Unexpected logs shape", data)
        return result

    def verify_source_code(self, **fields: Any) -> Dict[str, Any]:
        contract_name = fields.get("contractname") or fields.get("contract_name")
        compiler_version = fields.get("compilerversion") or fields.get("compiler_version")
        source_code = fields.get("sourceCode") or fields.get("source_code")
        if not source_code or not contract_name or not compiler_version:
            raise ValueError(
                "verify_source_code requires sourceCode, contractname, and compilerversion"
            )
        passthrough = {
            key: value
            for key, value in fields.items()
            if key
            not in {
                "sourceCode",
                "source_code",
                "contractname",
                "contract_name",
                "compilerversion",
                "compiler_version",
                "optimizationUsed",
                "optimization_used",
                "constructorArguements",
                "constructor_arguments",
                "evmversion",
                "evm_version",
                "licenseType",
                "license_type",
            }
        }
        return self.verify_contract(
            source_code=source_code,
            contract_name=contract_name,
            compiler_version=compiler_version,
            optimization_used=int(fields.get("optimizationUsed", fields.get("optimization_used", 1))),
            constructor_arguments=fields.get(
                "constructorArguements", fields.get("constructor_arguments", "")
            ),
            evm_version=fields.get("evmversion", fields.get("evm_version", "")),
            license_type=int(fields.get("licenseType", fields.get("license_type", 1))),
            **passthrough,
        )

    def check_verify_status(self, guid: str, **_: Any) -> Dict[str, Any]:
        return self._legacy(
            {
                "module": "contract",
                "action": "checkverifystatus",
                "guid": guid,
            }
        )


__all__ = ["EtherscanClient", "EtherscanAPIError", "EtherscanV2Error"]
