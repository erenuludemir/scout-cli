import os
import sys

import pytest  # noqa: F401

# Path bootstrap (must run before importing project modules)
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:  # pragma: no cover
    sys.path.insert(0, ROOT)

from integrations.etherscan.etherscan_v2 import EtherscanV2Client, EtherscanAPIError


class DummyClient(EtherscanV2Client):
    """Subclass that overrides _request to simulate API responses."""

    def __init__(self):
        super().__init__(base_url="https://api.etherscan.io/v2/api", api_key="TEST", chain_id=1)
        self.calls = []

    def _request(self, params):  # type: ignore[override]
        mod = params.get("module")
        self.calls.append(mod)
        if mod == "tokens":
            return {"status": "0", "message": "NOTOK", "result": "Invalid Module name (#2)"}
        return {"status": "1", "message": "OK", "result": [{"holder": "0xabc"}]}


def test_module_fallback_success():
    cli = DummyClient()
    data = cli.tokenholder_list("0x0000000000000000000000000000000000000000")
    assert data["status"] == "1"
    # Ensure both module attempts occurred
    assert cli.calls == ["tokens", "token"], cli.calls


def test_module_fallback_failure():
    class FailClient(DummyClient):
        def _request(self, params):  # type: ignore[override]
            _ = params.get("module")
            return {"status": "0", "message": "NOTOK", "result": "Invalid Module name (#2)"}

    fc = FailClient()
    with pytest.raises(EtherscanAPIError):
        fc.tokenholder_count("0x0000000000000000000000000000000000000000")
