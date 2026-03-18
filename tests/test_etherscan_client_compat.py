import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from integrations.etherscan.etherscan_client import EtherscanClient


class LegacyCompatClient(EtherscanClient):
    def __init__(self, **kwargs):
        super().__init__(api_key="TEST", base_url="https://api.etherscan.io/api", **kwargs)
        self.request_modules = []

    def _legacy(self, params):  # type: ignore[override]
        action = params.get("action")
        if action == "balance":
            return {"status": "1", "message": "OK", "result": "42"}
        if action == "tokenbalance":
            return {"status": "1", "message": "OK", "result": "7"}
        if action == "txlist":
            return {"status": "1", "message": "OK", "result": [{"hash": "0xabc"}]}
        if action == "getLogs":
            return {"status": "1", "message": "OK", "result": [{"logIndex": "0x1"}]}
        if action == "checkverifystatus":
            return {"status": "1", "message": "OK", "result": "Pass - Verified"}
        raise AssertionError(f"unexpected legacy action: {action}")

    def _request(self, params):  # type: ignore[override]
        self.request_modules.append(params.get("module"))
        if params.get("action") == "tokeninfo" and params.get("module") == "tokens":
            return {"status": "0", "message": "NOTOK", "result": "Invalid Module name (#2)"}
        return {"status": "1", "message": "OK", "result": [{"symbol": "USDT"}]}


class VerifyCompatClient(LegacyCompatClient):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.verify_kwargs = None

    def verify_contract(self, **kwargs):  # type: ignore[override]
        self.verify_kwargs = kwargs
        return {"status": "1", "message": "OK", "result": "guid-123"}


def test_etherscan_client_accepts_chainid_alias_and_legacy_helpers():
    cli = LegacyCompatClient(chainid=10)

    assert cli.chain_id == 10
    assert cli.get_balance_wei("0xabc") == 42
    assert cli.address_token_balance("0xabc", "0xdef", tag="latest") == 7
    assert cli.get_txlist("0xabc", page=2, offset=5) == [{"hash": "0xabc"}]
    assert cli.get_logs("0xabc", 0, 10) == [{"logIndex": "0x1"}]
    assert cli.check_verify_status("guid-123")["result"] == "Pass - Verified"


def test_etherscan_client_token_info_uses_module_fallback():
    cli = LegacyCompatClient()

    data = cli.token_info("0x0000000000000000000000000000000000000000")

    assert data["status"] == "1"
    assert cli.request_modules == ["tokens", "token"]


def test_verify_source_code_forwards_legacy_payload():
    cli = VerifyCompatClient()

    result = cli.verify_source_code(
        sourceCode="contract Foo {}",
        contractname="Foo",
        compilerversion="v0.8.28+commit.7893614a",
        contractaddress="0xabc",
        codeformat="solidity-single-file",
        runs=500,
        optimizationUsed=0,
    )

    assert result["status"] == "1"
    assert cli.verify_kwargs == {
        "source_code": "contract Foo {}",
        "contract_name": "Foo",
        "compiler_version": "v0.8.28+commit.7893614a",
        "optimization_used": 0,
        "constructor_arguments": "",
        "evm_version": "",
        "license_type": 1,
        "contractaddress": "0xabc",
        "codeformat": "solidity-single-file",
        "runs": 500,
    }
