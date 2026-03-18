from __future__ import annotations
import os, typing as t, requests

_DEFAULTS = {
    "1":  {"base_url": os.getenv("ETHERSCAN_API_URL", "https://api.etherscan.io/api"), "api_key": os.getenv("ETHERSCAN_API_KEY","")},
    "42161": {"base_url": os.getenv("ARBISCAN_API_URL", "https://api.arbiscan.io/api"), "api_key": os.getenv("ARBISCAN_API_KEY","")},
    "10": {"base_url": os.getenv("OPTIMISM_API_URL", "https://api-optimistic.etherscan.io/api"), "api_key": os.getenv("OPTIMISM_API_KEY","")},
    "56": {"base_url": os.getenv("BSCSCAN_API_URL", "https://api.bscscan.com/api"), "api_key": os.getenv("BSCSCAN_API_KEY","")},
    "43114": {"base_url": os.getenv("SNOWSCAN_API_URL", "https://api.snowscan.xyz/api"), "api_key": os.getenv("SNOWSCAN_API_KEY","")},
}

def _pick_chain(chainid: int|str|None, base_url: str|None, api_key: str|None):
    if base_url and api_key:
        return base_url.rstrip("/"), api_key.strip()
    cid = str(chainid or "1")
    conf = _DEFAULTS.get(cid, _DEFAULTS["1"])
    return conf["base_url"].rstrip("/"), conf["api_key"].strip()

class EtherscanClient:
    """
    V1 ve V2 (multi-chain) destekli basit istemci.
    V1: query param 'module'+'action'
    V2: zincir seçimi için 'chainid' (genel prensip), bazı uçlar yeni path/paramlarla gelir.
    """
    def __init__(self, api_key: str|None=None, base_url: str|None=None, chainid: int|str|None=None, timeout: int=20):
        bu, ak = _pick_chain(chainid, base_url, api_key)
        self.api_key  = ak
        self.base_url = bu
        if not self.api_key:
            raise RuntimeError("Etherscan API key missing for selected chain")
        self.chainid = str(chainid) if chainid is not None else None
        self.s = requests.Session()
        self.timeout = timeout

    def _get_json(self, url: str, **params) -> dict:
        p = {**params, "apikey": self.api_key}
        r = self.s.get(url, params=p, timeout=self.timeout)
        r.raise_for_status()
        data = r.json()
        if isinstance(data, dict) and str(data.get("status","1")) == "0" and str(data.get("message","")).lower().startswith("notok"):
            raise RuntimeError(f"Etherscan NOTOK: {data.get('result')}")
        return data

    def _get_v1(self, **params) -> dict:
        return self._get_json(self.base_url, **params)

    def get_balance_wei(self, address: str) -> int:
        j = self._get_v1(module="account", action="balance", address=address, tag="latest")
        return int(j.get("result", "0"))

    def get_txlist(self, address: str, start_block: int=0, end_block: int=99999999,
                   page: int=1, offset: int=100, sort: str="asc") -> list[dict]:
        j = self._get_v1(module="account", action="txlist", address=address,
                         startblock=start_block, endblock=end_block, page=page, offset=offset, sort=sort)
        res = j.get("result", [])
        return res if isinstance(res, list) else []

    def get_erc20_transfers(self, address: str, page: int=1, offset: int=100, sort: str="desc") -> list[dict]:
        j = self._get_v1(module="account", action="tokentx", address=address, page=page, offset=offset, sort=sort)
        res = j.get("result", [])
        return res if isinstance(res, list) else []

    def get_erc721_transfers(self, address: str, page: int=1, offset: int=100, sort: str="desc") -> list[dict]:
        j = self._get_v1(module="account", action="tokennfttx", address=address, page=page, offset=offset, sort=sort)
        res = j.get("result", [])
        return res if isinstance(res, list) else []

    def get_erc1155_transfers(self, address: str, page: int=1, offset: int=100, sort: str="desc") -> list[dict]:
        j = self._get_v1(module="account", action="token1155tx", address=address, page=page, offset=offset, sort=sort)
        res = j.get("result", [])
        return res if isinstance(res, list) else []

    def get_logs(self, address: str, from_block: int, to_block: int,
                 topic0: str|None=None, topic1: str|None=None, topic2: str|None=None, topic3: str|None=None,
                 topic0_1_opr: str|None=None, topic1_2_opr: str|None=None, topic2_3_opr: str|None=None,
                 page: int=1, offset: int=1000) -> list[dict]:
        """
        V1 logs.getLogs — topic operatörleri (topic0_1_opr & topic1_2_opr & topic2_3_opr)
        - örnek: topic0=0xddf252ad..., topic1=0x0000...<addr>, topic0_1_opr=and
        Bkz. BscScan/Etherscan getLogs topic operator dokümanları. 
        """
        params: dict[str,t.Any] = dict(module="logs", action="getLogs",
                                       address=address, fromBlock=from_block, toBlock=to_block,
                                       page=page, offset=offset)
        if topic0: params["topic0"]=topic0
        if topic1: params["topic1"]=topic1
        if topic2: params["topic2"]=topic2
        if topic3: params["topic3"]=topic3
        if topic0_1_opr: params["topic0_1_opr"] = topic0_1_opr
        if topic1_2_opr: params["topic1_2_opr"] = topic1_2_opr
        if topic2_3_opr: params["topic2_3_opr"] = topic2_3_opr
        j = self._get_v1(**params)
        res = j.get("result", [])
        return res if isinstance(res, list) else []

    def _v2_get(self, path: str, **params) -> dict:
        """
        V2 uçları için GET wrapper. Bazı sağlayıcılarda aynı base_url ile /api devam eder,
        bazılarında farklı subdomain kullanılır; burada basitçe base_url kullanıp path ekliyoruz.
        """
        url = self.base_url
        return self._get_json(url, **params, chainid=self.chainid) if self.chainid else self._get_json(url, **params)

    def token_info(self, contractaddress: str) -> dict:
        return self._v2_get(module="token", action="tokeninfo", contractaddress=contractaddress)

    def address_token_balance(self, address: str, contractaddress: str) -> dict:
        return self._v2_get(module="account", action="tokenbalance", address=address, contractaddress=contractaddress, tag="latest")

    def erc721_inventory(self, address: str, contractaddress: str, page: int=1, offset: int=50) -> dict:
        return self._v2_get(module="account", action="erc721inventory", address=address, contractaddress=contractaddress, page=page, offset=offset)

    def erc1155_inventory(self, address: str, contractaddress: str, page: int=1, offset: int=50) -> dict:
        return self._v2_get(module="account", action="erc1155inventory", address=address, contractaddress=contractaddress, page=page, offset=offset)

    def token_holder_list(self, contractaddress: str, page: int=1, offset: int=50) -> dict:
        return self._v2_get(module="token", action="tokenholderlist", contractaddress=contractaddress, page=page, offset=offset)

    def token_holder_count(self, contractaddress: str) -> dict:
        return self._v2_get(module="token", action="tokenholdercount", contractaddress=contractaddress)

    def verify_contract(self, **fields) -> dict:
        """
        Etherscan 'contract verify' için gerekli POST alanlarını pas-through gönderir.
        Temel alanlar: apikey, module=contract, action=verifysourcecode,
        contractaddress, sourceCode, codeformat, contractname, compilerversion, optimizationUsed, runs, evmversion, licenseType, constructorArguements, ...
        Bkz. Verification API parametre listesi. 
        """
        data = {"apikey": self.api_key, "module": "contract", "action": "verifysourcecode"}
        data.update(fields)
        r = self.s.post(self.base_url, data=data, timeout=self.timeout)
        r.raise_for_status()
        return r.json()
