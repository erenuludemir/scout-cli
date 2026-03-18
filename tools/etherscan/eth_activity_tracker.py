#!/usr/bin/env python3
import json
import os
import sys
import time
import urllib.parse
import urllib.request
from decimal import Decimal, getcontext

getcontext().prec = 50

API_URL = "https://api.etherscan.io/v2/api"
RATE_LIMIT_RESULT = "max calls per sec rate limit reached"


def fail(message: str, code: int = 1) -> None:
    print(json.dumps({"ok": False, "error": message}, ensure_ascii=False))
    raise SystemExit(code)


def wei_to_eth(wei_value) -> str:
    value = Decimal(str(wei_value)) / Decimal("1000000000000000000")
    normalized = value.normalize()
    text = format(normalized, "f")
    if "." in text:
        text = text.rstrip("0").rstrip(".")
    return text or "0"


def token_to_decimal(raw_value, decimals) -> str:
    try:
        scale = Decimal(10) ** int(str(decimals or "0"))
        value = Decimal(str(raw_value)) / scale
    except Exception:
        return str(raw_value)
    normalized = value.normalize()
    text = format(normalized, "f")
    if "." in text:
        text = text.rstrip("0").rstrip(".")
    return text or "0"


def fetch_json(url: str) -> dict:
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "QuantumAI-Etherscan-Tracker/1.0",
            "Accept": "application/json",
        },
    )

    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                raw = response.read().decode("utf-8", errors="replace")
        except Exception as exc:
            fail(f"request_failed:{exc}")

        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            fail(f"invalid_json_response:{raw[:500]}")

        result = str(data.get("result", "")).lower()
        if RATE_LIMIT_RESULT not in result or attempt == 2:
            return data

        time.sleep(attempt + 1)

    fail("unreachable")


def build_url(action: str, apikey: str, **params) -> str:
    query = {
        "chainid": str(params.pop("chainid", "1")),
        "module": str(params.pop("module", "account")),
        "action": action,
        "apikey": apikey,
    }
    for key, value in params.items():
        if value is None or value == "":
            continue
        query[key] = str(value)
    return f"{API_URL}?{urllib.parse.urlencode(query)}"


def normalize_tx(item: dict) -> dict:
    out = dict(item)
    if "value" in item:
        out["value_eth"] = wei_to_eth(item.get("value", "0"))
    return out


def normalize_tokentx(item: dict) -> dict:
    out = dict(item)
    if "value" in item:
        out["value_decimal"] = token_to_decimal(item.get("value", "0"), item.get("tokenDecimal", "0"))
    return out


def normalize_portfolio_item(item: dict) -> dict:
    out = dict(item)
    decimals = item.get("TokenDivisor") or item.get("tokenDecimal") or item.get("decimals") or "0"
    balance = item.get("TokenQuantity") or item.get("balance") or item.get("tokenBalance") or item.get("Balance") or "0"
    out["balance_decimal"] = token_to_decimal(balance, decimals)
    return out


def fetch_list(url: str, item_normalizer):
    data = fetch_json(url)
    status = str(data.get("status", ""))
    message = str(data.get("message", ""))
    result = data.get("result")

    if status not in {"1", "0"}:
        fail(f"etherscan_error:status={status}:message={message}:result={result}")

    if isinstance(result, str):
        lowered = result.strip().lower()
        if lowered in {"", "null", "no transactions found", "no token transfers found", "no records found"}:
            result = []
        else:
            fail(f"etherscan_error:status={status}:message={message}:result={result}")

    if result in (None, "", "null"):
        result = []

    if not isinstance(result, list):
        fail(f"unexpected_result_type:{type(result).__name__}")

    return {
        "ok": True,
        "status": status,
        "message": message,
        "count": len(result),
        "items": [item_normalizer(item) for item in result],
    }


def get_txlist(address: str, chainid: str, apikey: str, page: str, offset: str, sort: str) -> dict:
    url = build_url(
        "txlist",
        apikey=apikey,
        address=address,
        chainid=chainid,
        startblock="0",
        endblock="9999999999",
        page=page,
        offset=offset,
        sort=sort,
    )
    result = fetch_list(url, normalize_tx)
    result.update(
        {
            "source": "etherscan_v2",
            "mode": "txlist",
            "chainid": str(chainid),
            "address": address,
            "page": str(page),
            "offset": str(offset),
            "sort": str(sort),
        }
    )
    return result


def get_tokentx(
    address: str,
    chainid: str,
    apikey: str,
    contractaddress: str,
    page: str,
    offset: str,
    sort: str,
) -> dict:
    url = build_url(
        "tokentx",
        apikey=apikey,
        address=address,
        chainid=chainid,
        contractaddress=contractaddress,
        startblock="0",
        endblock="9999999999",
        page=page,
        offset=offset,
        sort=sort,
    )
    result = fetch_list(url, normalize_tokentx)
    result.update(
        {
            "source": "etherscan_v2",
            "mode": "tokentx",
            "chainid": str(chainid),
            "address": address,
            "contractaddress": contractaddress or "",
            "page": str(page),
            "offset": str(offset),
            "sort": str(sort),
        }
    )
    return result


def get_portfolio(address: str, chainid: str, apikey: str) -> dict:
    url = build_url(
        "addresstokenbalance",
        apikey=apikey,
        address=address,
        chainid=chainid,
    )
    result = fetch_list(url, normalize_portfolio_item)
    result.update(
        {
            "source": "etherscan_v2",
            "mode": "portfolio",
            "chainid": str(chainid),
            "address": address,
        }
    )
    return result


def load_api_key() -> str:
    key = os.getenv("ETHERSCAN_API_KEY", "").strip()
    if not key:
        key = os.getenv("API_KEY_ETHERSCAN", "").strip()
    return key


def validate_address(address: str) -> None:
    if not address.startswith("0x") or len(address) != 42:
        fail("invalid_address")


def validate_chainid(chainid: str) -> None:
    if not chainid.isdigit():
        fail("invalid_chainid")


def validate_sort(sort: str) -> None:
    if sort not in {"asc", "desc"}:
        fail("invalid_sort")


def validate_positive_int(name: str, value: str) -> None:
    if not str(value).isdigit() or int(str(value)) <= 0:
        fail(f"invalid_{name}")


def main() -> None:
    if len(sys.argv) < 3:
        fail("usage: eth_activity_tracker.py <txlist|tokentx|portfolio> <address> [chainid] [extra...]")

    mode = sys.argv[1].strip().lower()
    address = sys.argv[2].strip()
    chainid = sys.argv[3].strip() if len(sys.argv) > 3 else "1"
    apikey = load_api_key()

    if not apikey:
        fail("ETHERSCAN_API_KEY missing")

    validate_address(address)
    validate_chainid(chainid)

    if mode == "txlist":
        page = sys.argv[4].strip() if len(sys.argv) > 4 else "1"
        offset = sys.argv[5].strip() if len(sys.argv) > 5 else "10"
        sort = sys.argv[6].strip() if len(sys.argv) > 6 else "desc"
        validate_positive_int("page", page)
        validate_positive_int("offset", offset)
        validate_sort(sort)
        result = get_txlist(address=address, chainid=chainid, apikey=apikey, page=page, offset=offset, sort=sort)
    elif mode == "tokentx":
        contractaddress = sys.argv[4].strip() if len(sys.argv) > 4 else ""
        page = sys.argv[5].strip() if len(sys.argv) > 5 else "1"
        offset = sys.argv[6].strip() if len(sys.argv) > 6 else "10"
        sort = sys.argv[7].strip() if len(sys.argv) > 7 else "desc"
        if contractaddress:
            validate_address(contractaddress)
        validate_positive_int("page", page)
        validate_positive_int("offset", offset)
        validate_sort(sort)
        result = get_tokentx(
            address=address,
            chainid=chainid,
            apikey=apikey,
            contractaddress=contractaddress,
            page=page,
            offset=offset,
            sort=sort,
        )
    elif mode == "portfolio":
        result = get_portfolio(address=address, chainid=chainid, apikey=apikey)
    else:
        fail("invalid_mode")

    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
