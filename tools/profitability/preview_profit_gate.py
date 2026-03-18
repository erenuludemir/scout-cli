#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP, getcontext
from urllib.parse import urlparse
from typing import Any

getcontext().prec = 28

DEFAULT_GATEWAY_URL = "http://127.0.0.1:5003"
DEFAULT_AMOUNTS = "100,250,500,1000"
DEFAULT_TARGET_EDGE_BPS = "120"
DEFAULT_MIN_PROFIT_USD = "5"
DEFAULT_SLIPPAGE_BPS = "50"
QUOTE_TIMEOUT_SECS = 10

USD_PRICES = {
    "ETH": Decimal("3000"),
    "WETH": Decimal("3000"),
    "USDT": Decimal("1"),
    "USDC": Decimal("1"),
    "DAI": Decimal("1"),
    "WBTC": Decimal("65000"),
}


def fail(message: str, code: int = 1) -> None:
    print(json.dumps({"ok": False, "error": message}, ensure_ascii=False))
    raise SystemExit(code)


def parse_decimal(value: str, field_name: str) -> Decimal:
    try:
        parsed = Decimal(str(value))
    except (InvalidOperation, TypeError, ValueError):
        fail(f"invalid_{field_name}")
    if parsed <= 0:
        fail(f"invalid_{field_name}")
    return parsed


def parse_int(value: str, field_name: str) -> int:
    try:
        parsed = int(str(value))
    except (TypeError, ValueError):
        fail(f"invalid_{field_name}")
    if parsed < 0:
        fail(f"invalid_{field_name}")
    return parsed


def parse_amounts(raw: str) -> list[Decimal]:
    amounts: list[Decimal] = []
    for part in str(raw or "").split(","):
        token = part.strip()
        if not token:
            continue
        amounts.append(parse_decimal(token, "amounts"))
    if not amounts:
        fail("invalid_amounts")
    return amounts


def normalize_symbol(raw: str) -> str:
    symbol = str(raw or "").strip().upper()
    if not symbol:
        fail("invalid_symbol")
    if symbol == "BTC":
        return "WBTC"
    return symbol


def decimal_to_float(value: Decimal, places: str = "0.00000001") -> float:
    quantized = value.quantize(Decimal(places), rounding=ROUND_HALF_UP)
    return float(quantized)


def quote_urls(base_url: str) -> list[str]:
    normalized = base_url.rstrip("/")
    parsed = urlparse(normalized)
    path = parsed.path.rstrip("/")
    if path.endswith("/quote"):
        return [normalized]
    if path.endswith("/dex"):
        return [f"{normalized}/quote"]
    return [f"{normalized}/quote", f"{normalized}/dex/quote"]


def fetch_quote(
    gateway_url: str,
    *,
    from_token: str,
    to_token: str,
    amount_in: Decimal,
    slippage_bps: int,
) -> dict[str, Any]:
    payload = json.dumps(
        {
            "from_token": from_token,
            "to_token": to_token,
            "amount_in": format(amount_in.normalize(), "f"),
            "slippage_bps": slippage_bps,
        }
    ).encode("utf-8")
    last_http_error = ""
    for url in quote_urls(gateway_url):
        request = urllib.request.Request(
            url,
            data=payload,
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json",
                "User-Agent": "QuantumAI-Profit-Gate/1.0",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=QUOTE_TIMEOUT_SECS) as response:
                raw = response.read().decode("utf-8", errors="replace")
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            last_http_error = f"quote_http_error:{exc.code}:{body[:200]}"
            if exc.code == 404:
                continue
            fail(last_http_error)
        except urllib.error.URLError as exc:
            fail(f"quote_unreachable:{exc.reason}")
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            fail(f"invalid_quote_json:{raw[:200]}")
        if not data.get("ok"):
            fail(f"quote_error:{data}")
        return data

    fail(last_http_error or "quote_unreachable")


def evaluate_candidate(
    quote: dict[str, Any],
    *,
    amount_in: Decimal,
    target_edge_bps: Decimal,
    min_profit_usd: Decimal,
) -> dict[str, Any]:
    from_token = normalize_symbol(str(quote["from_token"]))
    to_token = normalize_symbol(str(quote["to_token"]))
    if from_token not in USD_PRICES or to_token not in USD_PRICES:
        fail("unsupported_quote_symbol")

    amount_in_usd = amount_in * USD_PRICES[from_token]
    fee_bps = Decimal(str(quote.get("fee_bps", 0)))
    price_impact_bps = Decimal(str(quote.get("price_impact_bps", 0)))
    slippage_bps = Decimal(str(quote.get("slippage_bps", 0)))
    network_fee_usd = Decimal(str(quote.get("estimated_network_fee_usd", 0)))

    fee_cost_usd = amount_in_usd * fee_bps / Decimal("10000")
    impact_cost_usd = amount_in_usd * price_impact_bps / Decimal("10000")
    slippage_buffer_usd = amount_in_usd * slippage_bps / Decimal("10000")
    gross_edge_usd = amount_in_usd * target_edge_bps / Decimal("10000")
    total_cost_usd = fee_cost_usd + impact_cost_usd + slippage_buffer_usd + network_fee_usd
    expected_profit_usd = gross_edge_usd - total_cost_usd
    break_even_edge_bps = (
        Decimal("0")
        if amount_in_usd == 0
        else total_cost_usd / amount_in_usd * Decimal("10000")
    )
    profitable = expected_profit_usd >= min_profit_usd

    return {
        "pair": f"{from_token}/{to_token}",
        "amount_in": decimal_to_float(amount_in),
        "amount_in_usd": decimal_to_float(amount_in_usd),
        "quote_out": quote.get("quote_out"),
        "quote_out_raw": quote.get("quote_out_raw"),
        "route": quote.get("route"),
        "path": quote.get("path"),
        "fee_bps": int(fee_bps),
        "price_impact_bps": int(price_impact_bps),
        "slippage_bps": int(slippage_bps),
        "estimated_network_fee_usd": decimal_to_float(network_fee_usd),
        "break_even_edge_bps": decimal_to_float(break_even_edge_bps),
        "target_edge_bps": decimal_to_float(target_edge_bps),
        "gross_edge_usd": decimal_to_float(gross_edge_usd),
        "total_cost_usd": decimal_to_float(total_cost_usd),
        "expected_profit_usd": decimal_to_float(expected_profit_usd),
        "min_profit_usd": decimal_to_float(min_profit_usd),
        "profitable": profitable,
        "action": "candidate" if profitable else "skip",
    }


def best_candidate(candidates: list[dict[str, Any]]) -> dict[str, Any] | None:
    if not candidates:
        return None

    def key(candidate: dict[str, Any]) -> tuple[int, Decimal]:
        return (
            1 if candidate["profitable"] else 0,
            Decimal(str(candidate["expected_profit_usd"])),
        )

    return max(candidates, key=key)


def main() -> None:
    from_token = normalize_symbol(sys.argv[1] if len(sys.argv) > 1 else "USDT")
    to_token = normalize_symbol(sys.argv[2] if len(sys.argv) > 2 else "ETH")
    amounts = parse_amounts(sys.argv[3] if len(sys.argv) > 3 else DEFAULT_AMOUNTS)
    target_edge_bps = parse_decimal(
        sys.argv[4] if len(sys.argv) > 4 else DEFAULT_TARGET_EDGE_BPS,
        "target_edge_bps",
    )
    min_profit_usd = parse_decimal(
        sys.argv[5] if len(sys.argv) > 5 else DEFAULT_MIN_PROFIT_USD,
        "min_profit_usd",
    )
    slippage_bps = parse_int(
        sys.argv[6] if len(sys.argv) > 6 else DEFAULT_SLIPPAGE_BPS,
        "slippage_bps",
    )
    gateway_url = sys.argv[7].strip() if len(sys.argv) > 7 else DEFAULT_GATEWAY_URL
    if not gateway_url:
        fail("invalid_gateway_url")

    candidates: list[dict[str, Any]] = []
    for amount in amounts:
        quote = fetch_quote(
            gateway_url,
            from_token=from_token,
            to_token=to_token,
            amount_in=amount,
            slippage_bps=slippage_bps,
        )
        candidates.append(
            evaluate_candidate(
                quote,
                amount_in=amount,
                target_edge_bps=target_edge_bps,
                min_profit_usd=min_profit_usd,
            )
        )

    profitable_count = sum(1 for item in candidates if item["profitable"])
    result = {
        "ok": True,
        "mode": "preview_profit_scan",
        "gateway_url": gateway_url,
        "pair": f"{from_token}/{to_token}",
        "target_edge_bps": decimal_to_float(target_edge_bps),
        "min_profit_usd": decimal_to_float(min_profit_usd),
        "slippage_bps": slippage_bps,
        "candidates": candidates,
        "best_candidate": best_candidate(candidates),
        "profitable_count": profitable_count,
        "recommended_action": "candidate" if profitable_count else "monitor",
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
