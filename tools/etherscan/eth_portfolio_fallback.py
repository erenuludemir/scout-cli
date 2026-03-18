#!/usr/bin/env python3
import json
import os
import sys
from decimal import Decimal, getcontext

from eth_balance_tracker import get_balance
from eth_activity_tracker import get_tokentx

getcontext().prec = 50

DEFAULT_TRACKED_CONTRACTS = [
    "0xdac17f958d2ee523a2206206994597c13d831ec7",
    "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
]


def fail(message: str, code: int = 1) -> None:
    print(json.dumps({"ok": False, "error": message}, ensure_ascii=False))
    raise SystemExit(code)


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


def parse_contracts(raw: str) -> list[str]:
    if not raw:
        return DEFAULT_TRACKED_CONTRACTS[:]
    contracts = []
    for item in raw.split(","):
        addr = item.strip()
        if not addr:
            continue
        if not addr.startswith("0x") or len(addr) != 42:
            fail(f"invalid_contractaddress:{addr}")
        contracts.append(addr)
    return contracts or DEFAULT_TRACKED_CONTRACTS[:]


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


def summarize_tokentx_for_address(address: str, tx_items: list[dict]) -> dict:
    address_l = address.lower()
    net_raw = Decimal("0")
    token_symbol = ""
    token_name = ""
    token_decimal = "0"
    contract_address = ""
    incoming_count = 0
    outgoing_count = 0
    latest_txhash = ""

    for item in tx_items:
        from_addr = str(item.get("from", "")).lower()
        to_addr = str(item.get("to", "")).lower()
        value_raw = Decimal(str(item.get("value", "0")))
        token_decimal = str(item.get("tokenDecimal", token_decimal or "0"))
        token_symbol = str(item.get("tokenSymbol", token_symbol or ""))
        token_name = str(item.get("tokenName", token_name or ""))
        contract_address = str(item.get("contractAddress", contract_address or ""))
        latest_txhash = str(item.get("hash", latest_txhash or ""))

        if to_addr == address_l:
            net_raw += value_raw
            incoming_count += 1
        if from_addr == address_l:
            net_raw -= value_raw
            outgoing_count += 1

    return {
        "contractAddress": contract_address,
        "tokenSymbol": token_symbol,
        "tokenName": token_name,
        "tokenDecimal": token_decimal,
        "net_raw": str(net_raw),
        "net_balance_decimal": token_to_decimal(net_raw, token_decimal),
        "incoming_count": incoming_count,
        "outgoing_count": outgoing_count,
        "latest_txhash": latest_txhash,
    }


def build_fallback_portfolio(
    address: str,
    chainid: str,
    apikey: str,
    contracts: list[str],
    offset: str = "100",
) -> dict:
    native = get_balance(address=address, chainid=chainid, apikey=apikey)

    tokens = []
    for contract in contracts:
        result = get_tokentx(
            address=address,
            chainid=chainid,
            apikey=apikey,
            contractaddress=contract,
            page="1",
            offset=offset,
            sort="desc",
        )
        summary = summarize_tokentx_for_address(address=address, tx_items=result.get("items", []))
        summary["query_count"] = result.get("count", 0)
        tokens.append(summary)

    tokens = [t for t in tokens if Decimal(t["net_raw"]) != 0]
    tokens.sort(key=lambda item: abs(Decimal(item["net_raw"])), reverse=True)

    return {
        "ok": True,
        "source": "etherscan_v2_fallback",
        "mode": "portfolio_fallback",
        "portfolio_mode": "native_plus_tokentx_summary",
        "chainid": str(chainid),
        "address": address,
        "native": native,
        "tracked_contracts": contracts,
        "token_count": len(tokens),
        "tokens": tokens,
        "note": "Read-only fallback summary. Token balances are approximated from recent ERC20 transfer history for tracked contracts only.",
    }


def main() -> None:
    if len(sys.argv) < 2:
        fail("usage: eth_portfolio_fallback.py <address> [chainid] [contract1,contract2,...]")

    address = sys.argv[1].strip()
    chainid = sys.argv[2].strip() if len(sys.argv) > 2 else "1"
    contracts_raw = sys.argv[3].strip() if len(sys.argv) > 3 else ""

    apikey = load_api_key()
    if not apikey:
        fail("ETHERSCAN_API_KEY missing")

    validate_address(address)
    validate_chainid(chainid)
    contracts = parse_contracts(contracts_raw)

    result = build_fallback_portfolio(
        address=address,
        chainid=chainid,
        apikey=apikey,
        contracts=contracts,
    )
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
