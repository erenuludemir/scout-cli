import os
import time
import requests
from urllib.parse import urlencode

class EtherscanV2Client:
    """
    Basit, senkron Etherscan v2 istemcisi (Accounts modülü ağırlıklı).
    Zincir seçimi için 'chainid' parametresi kullanılır (varsayılan: 1).
    """
    def __init__(self, api_key: str, chain_id: int = 1, base_url: str = "https://api.etherscan.io/v2/api", timeout=20):
        self.api_key = api_key
        self.chain_id = chain_id
        self.base_url = base_url
        self.timeout = timeout

    def _get(self, module: str, action: str, **params):
        q = {
            "chainid": self.chain_id,
            "module": module,
            "action": action,
            "apikey": self.api_key,
        }
        q.update({k: v for k, v in params.items() if v is not None})
        url = f"{self.base_url}?{urlencode(q, doseq=True)}"
        r = requests.get(url, timeout=self.timeout)
        r.raise_for_status()
        return r.json()

    def balance(self, address: str, tag: str = "latest"):
        return self._get("account", "balance", address=address, tag=tag)

    def balancemulti(self, addresses: list, tag: str = "latest"):
        return self._get("account", "balancemulti", address=",".join(addresses), tag=tag)

    def txlist(self, address: str, startblock=0, endblock=99999999, page=1, offset=10, sort="asc"):
        return self._get("account", "txlist", address=address, startblock=startblock, endblock=endblock,
                         page=page, offset=offset, sort=sort)

    def txlistinternal_by_address(self, address: str, startblock=0, endblock=99999999, page=1, offset=10, sort="asc"):
        return self._get("account", "txlistinternal", address=address, startblock=startblock,
                         endblock=endblock, page=page, offset=offset, sort=sort)

    def txlistinternal_by_txhash(self, txhash: str):
        return self._get("account", "txlistinternal", txhash=txhash)

    def txlistinternal_by_blockrange(self, startblock: int, endblock: int, page=1, offset=10, sort="asc"):
        return self._get("account", "txlistinternal", startblock=startblock, endblock=endblock,
                         page=page, offset=offset, sort=sort)

    def tokentx(self, address: str=None, contractaddress: str=None, page=1, offset=100, startblock=0, endblock=99999999, sort="asc"):
        return self._get("account", "tokentx", address=address, contractaddress=contractaddress, page=page,
                         offset=offset, startblock=startblock, endblock=endblock, sort=sort)

    def tokennfttx(self, address: str=None, contractaddress: str=None, page=1, offset=100, startblock=0, endblock=99999999, sort="asc"):
        return self._get("account", "tokennfttx", address=address, contractaddress=contractaddress, page=page,
                         offset=offset, startblock=startblock, endblock=endblock, sort=sort)

    def token1155tx(self, address: str=None, contractaddress: str=None, page=1, offset=100, startblock=0, endblock=99999999, sort="asc"):
        return self._get("account", "token1155tx", address=address, contractaddress=contractaddress, page=page,
                         offset=offset, startblock=startblock, endblock=endblock, sort=sort)

    def fundedby(self, address: str):
        return self._get("account", "fundedby", address=address)

    def getminedblocks(self, address: str, blocktype: str="blocks", page=1, offset=10):
        return self._get("account", "getminedblocks", address=address, blocktype=blocktype, page=page, offset=offset)
