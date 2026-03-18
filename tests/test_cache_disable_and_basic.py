import os
import sys
import time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)

from integrations import cache as cache_mod
from integrations.etherscan.etherscan_v2 import EtherscanV2Client


class DummyCacheClient:
    def __init__(self):
        self.calls = 0
        self._cache = {}  # (contract, offset) -> (resp_dict, timestamp)

    def get_token_holders(self, contract: str, offset: int = 0):
        key = (contract, offset)
        disable = os.getenv("DISABLE_CACHE", "").lower() in ("1", "true", "yes", "on")
        try:
            ttl = int(os.getenv("ETHERSCAN_CACHE_TTL", "0") or "0")
        except ValueError:
            ttl = 0
        now = time.time()

        if not disable and key in self._cache:
            data, ts = self._cache[key]
            if ttl <= 0 or (now - ts) < ttl:
                cached = data.copy()
                cached["cached"] = True
                return cached
            else:
                del self._cache[key]

        # Simulate external fetch
        self.calls += 1
        params = {
            "module": "tokens",
            "action": "tokenholderlist",
            "contractaddress": contract,
            "offset": offset,
        }
        resp = {
            "status": "1",
            "message": "OK",
            "result": [{"holder": "0xabc"}],
            "_echo": params,
        }
        if not disable:
            self._cache[key] = (resp, now)
        return resp


def test_cache_disabled():
    os.environ["DISABLE_CACHE"] = "1"
    os.environ["ETHERSCAN_CACHE_TTL"] = "60"
    cli = DummyCacheClient()
    cli.get_token_holders("0x0000000000000000000000000000000000000000", offset=2)
    second = cli.get_token_holders("0x0000000000000000000000000000000000000000", offset=2)
    assert "cached" not in second
    os.environ.pop("DISABLE_CACHE")


def test_cache_enabled():
    os.environ["ETHERSCAN_CACHE_TTL"] = "120"
    if "DISABLE_CACHE" in os.environ:
        del os.environ["DISABLE_CACHE"]
    cli = DummyCacheClient()
    cli.get_token_holders("0x0000000000000000000000000000000000000000", offset=2)
    cached_resp = cli.get_token_holders("0x0000000000000000000000000000000000000000", offset=2)
    assert cached_resp.get("cached") is True


class StubTokenholderClient(EtherscanV2Client):
    def __init__(self):
        super().__init__(base_url="https://api.etherscan.io/v2/api", api_key="TEST", chain_id=1)
        self.calls = 0

    def _request(self, params):  # type: ignore[override]
        self.calls += 1
        return {
            "status": "1",
            "message": "OK",
            "result": [{"holder": "0xabc"}],
            "_echo": params,
        }


def test_cache_helper_ttl_zero_is_non_expiring(monkeypatch):
    monkeypatch.delenv("REDIS_URL", raising=False)
    monkeypatch.setattr(cache_mod, "_redis_client", None)
    cache_mod.cache_clear()

    cache_mod.cache_set("demo", {"ok": True}, 0)

    assert cache_mod.cache_get_value("demo") == {"ok": True}


def test_real_tokenholder_cache_enabled(monkeypatch):
    monkeypatch.delenv("REDIS_URL", raising=False)
    monkeypatch.delenv("DISABLE_CACHE", raising=False)
    monkeypatch.setenv("ETHERSCAN_CACHE_TTL", "120")
    monkeypatch.setattr(cache_mod, "_redis_client", None)
    cache_mod.cache_clear()

    cli = StubTokenholderClient()
    first = cli.tokenholder_list("0x0000000000000000000000000000000000000000", offset=2)
    second = cli.tokenholder_list("0x0000000000000000000000000000000000000000", offset=2)

    assert first.get("cached") is None
    assert second.get("cached") is True
    assert cli.calls == 1


def test_real_tokenholder_cache_disabled(monkeypatch):
    monkeypatch.delenv("REDIS_URL", raising=False)
    monkeypatch.setenv("DISABLE_CACHE", "1")
    monkeypatch.setenv("ETHERSCAN_CACHE_TTL", "120")
    monkeypatch.setattr(cache_mod, "_redis_client", None)
    cache_mod.cache_clear()

    cli = StubTokenholderClient()
    first = cli.tokenholder_list("0x0000000000000000000000000000000000000000", offset=2)
    second = cli.tokenholder_list("0x0000000000000000000000000000000000000000", offset=2)

    assert first.get("cached") is None
    assert second.get("cached") is None
    assert cli.calls == 2
