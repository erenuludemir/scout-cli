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


def wei_to_eth(wei_value: str) -> str:
    value = Decimal(wei_value) / Decimal("1000000000000000000")
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


def build_url(address: str, chainid: str, apikey: str) -> str:
    params = {
        "chainid": chainid,
        "module": "account",
        "action": "balance",
        "address": address,
        "tag": "latest",
        "apikey": apikey,
    }
    return f"{API_URL}?{urllib.parse.urlencode(params)}"


def get_balance(address: str, chainid: str, apikey: str) -> dict:
    url = build_url(address=address, chainid=chainid, apikey=apikey)
    data = fetch_json(url)

    status = str(data.get("status", ""))
    message = str(data.get("message", ""))
    result = data.get("result")

    if status != "1":
        fail(f"etherscan_error:status={status}:message={message}:result={result}")

    balance_wei = str(result)
    return {
        "ok": True,
        "source": "etherscan_v2",
        "chainid": str(chainid),
        "address": address,
        "balance_wei": balance_wei,
        "balance_eth": wei_to_eth(balance_wei),
    }


def main() -> None:
    if len(sys.argv) < 2:
        fail("usage: eth_balance_tracker.py <address> [chainid]")

    address = sys.argv[1].strip()
    chainid = sys.argv[2].strip() if len(sys.argv) > 2 else "1"
    apikey = os.getenv("ETHERSCAN_API_KEY", "").strip()

    if not apikey:
        fail("ETHERSCAN_API_KEY missing")
    if not address.startswith("0x") or len(address) != 42:
        fail("invalid_address")
    if not chainid.isdigit():
        fail("invalid_chainid")

    result = get_balance(address=address, chainid=chainid, apikey=apikey)
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
