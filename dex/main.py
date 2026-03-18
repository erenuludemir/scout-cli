from __future__ import annotations

import time
from decimal import Decimal, InvalidOperation, ROUND_DOWN, getcontext
from typing import Any

from flask import Flask, jsonify, request

getcontext().prec = 28

SUPPORTED_DECIMALS = {
    "ETH": 18,
    "WETH": 18,
    "USDT": 6,
    "USDC": 6,
    "DAI": 18,
    "WBTC": 8,
}
USD_PRICES = {
    "ETH": Decimal("3000"),
    "WETH": Decimal("3000"),
    "USDT": Decimal("1"),
    "USDC": Decimal("1"),
    "DAI": Decimal("1"),
    "WBTC": Decimal("65000"),
}
SYMBOL_ALIASES = {
    "BTC": "WBTC",
}
STABLES = {"USDT", "USDC", "DAI"}
DEFAULT_SLIPPAGE_BPS = 50
DEFAULT_GAS_PRICE_GWEI = Decimal("18")


def create_app() -> Flask:
    app = Flask(__name__)
    started_at = time.time()

    def register_dual_route(rule: str, endpoint: str, view_func: Any, methods: list[str]) -> None:
        app.add_url_rule(rule, endpoint, view_func=view_func, methods=methods)
        app.add_url_rule(f"/dex{rule}", f"dex_{endpoint}", view_func=view_func, methods=methods)

    def json_error(message: str, status_code: int = 400):
        return jsonify(ok=False, status="error", error=message), status_code

    def normalize_symbol(raw: Any) -> str:
        symbol = str(raw or "").strip().upper()
        if not symbol:
            return ""
        return SYMBOL_ALIASES.get(symbol, symbol)

    def display_to_raw(amount: Decimal, decimals: int) -> int:
        scale = Decimal(10) ** decimals
        return int((amount * scale).to_integral_value(rounding=ROUND_DOWN))

    def raw_to_display(raw_amount: int, decimals: int) -> Decimal:
        scale = Decimal(10) ** decimals
        return Decimal(raw_amount) / scale

    def decimal_to_float(value: Decimal, places: str = "0.00000001") -> float:
        return float(value.quantize(Decimal(places)))

    def parse_decimal(raw: Any, field_name: str) -> Decimal:
        try:
            value = Decimal(str(raw))
        except (InvalidOperation, ValueError, TypeError):
            raise ValueError(f"{field_name} must be numeric") from None
        if value <= 0:
            raise ValueError(f"{field_name} must be greater than zero")
        return value

    def parse_int(raw: Any, field_name: str) -> int:
        try:
            value = int(str(raw))
        except (ValueError, TypeError):
            raise ValueError(f"{field_name} must be an integer") from None
        if value <= 0:
            raise ValueError(f"{field_name} must be greater than zero")
        return value

    def extract(payload: dict[str, Any], *names: str) -> Any:
        for name in names:
            if name in payload and payload[name] not in (None, ""):
                return payload[name]
        return None

    def parse_request(payload: dict[str, Any]) -> dict[str, Any]:
        from_symbol = normalize_symbol(extract(payload, "from_token", "from"))
        to_symbol = normalize_symbol(extract(payload, "to_token", "to"))
        if not from_symbol or not to_symbol:
            raise ValueError("from_token/to_token are required")
        if from_symbol not in SUPPORTED_DECIMALS:
            raise ValueError(f"unsupported from_token '{from_symbol}'")
        if to_symbol not in SUPPORTED_DECIMALS:
            raise ValueError(f"unsupported to_token '{to_symbol}'")
        if from_symbol == to_symbol:
            raise ValueError("from_token and to_token must be different")

        raw_amount = extract(payload, "amount", "amount_in_raw", "amount_raw")
        display_amount = extract(payload, "amount_in", "amount_display")
        if raw_amount is None and display_amount is None:
            raise ValueError("amount or amount_in is required")

        from_decimals = SUPPORTED_DECIMALS[from_symbol]
        if raw_amount is not None:
            amount_in_raw = parse_int(raw_amount, "amount")
            amount_in_display = raw_to_display(amount_in_raw, from_decimals)
        else:
            amount_in_display = parse_decimal(display_amount, "amount_in")
            amount_in_raw = display_to_raw(amount_in_display, from_decimals)

        slippage_bps = int(extract(payload, "slippage_bps") or DEFAULT_SLIPPAGE_BPS)
        if slippage_bps < 0 or slippage_bps > 5000:
            raise ValueError("slippage_bps must be between 0 and 5000")

        return {
            "from_symbol": from_symbol,
            "to_symbol": to_symbol,
            "from_decimals": from_decimals,
            "to_decimals": SUPPORTED_DECIMALS[to_symbol],
            "amount_in_raw": amount_in_raw,
            "amount_in_display": amount_in_display,
            "slippage_bps": slippage_bps,
        }

    def router_symbol(symbol: str) -> str:
        return "WETH" if symbol == "ETH" else symbol

    def route_path(from_symbol: str, to_symbol: str) -> list[str]:
        origin = router_symbol(from_symbol)
        target = router_symbol(to_symbol)
        if origin == target:
            return [origin]
        if origin in STABLES and target in STABLES:
            return [origin, target]
        if "WETH" in (origin, target):
            return [origin, target]
        return [origin, "WETH", target]

    def build_quote(parsed: dict[str, Any]) -> dict[str, Any]:
        path = route_path(parsed["from_symbol"], parsed["to_symbol"])
        hops = max(len(path) - 1, 0)
        route = "direct" if hops <= 1 else "via-weth"

        price_in = USD_PRICES[parsed["from_symbol"]]
        price_out = USD_PRICES[parsed["to_symbol"]]
        mid_price = price_in / price_out
        fee_bps = hops * 30

        amount_usd = parsed["amount_in_display"] * price_in
        liquidity_usd = Decimal("2000000") if route == "direct" else Decimal("750000")
        price_impact_bps = int(
            min(
                Decimal("900"),
                max(
                    Decimal("3"),
                    (amount_usd / liquidity_usd) * Decimal("10000"),
                ),
            ).to_integral_value(rounding=ROUND_DOWN)
        )

        fee_multiplier = Decimal("1") - (Decimal(fee_bps) / Decimal("10000"))
        impact_multiplier = Decimal("1") - (Decimal(price_impact_bps) / Decimal("10000"))
        quoted_out_display = parsed["amount_in_display"] * mid_price * fee_multiplier * impact_multiplier
        min_out_display = quoted_out_display * (
            Decimal("1") - (Decimal(parsed["slippage_bps"]) / Decimal("10000"))
        )

        quoted_out_raw = display_to_raw(quoted_out_display, parsed["to_decimals"])
        min_out_raw = display_to_raw(min_out_display, parsed["to_decimals"])

        gas_estimate = 110000 if route == "direct" else 160000
        network_fee_native = (
            Decimal(gas_estimate) * DEFAULT_GAS_PRICE_GWEI / Decimal("1000000000")
        )
        network_fee_usd = network_fee_native * USD_PRICES["ETH"]

        return {
            "ok": True,
            "status": "ok",
            "mode": "preview",
            "price_source": "static",
            "execution_enabled": False,
            "from_token": parsed["from_symbol"],
            "to_token": parsed["to_symbol"],
            "amount_in": decimal_to_float(parsed["amount_in_display"]),
            "amount_in_raw": str(parsed["amount_in_raw"]),
            "quote_out": decimal_to_float(quoted_out_display),
            "quote_out_raw": str(quoted_out_raw),
            "min_out": decimal_to_float(min_out_display),
            "min_out_raw": str(min_out_raw),
            "slippage_bps": parsed["slippage_bps"],
            "price_impact_bps": price_impact_bps,
            "fee_bps": fee_bps,
            "gas_estimate": gas_estimate,
            "estimated_network_fee_eth": decimal_to_float(network_fee_native),
            "estimated_network_fee_usd": decimal_to_float(network_fee_usd),
            "pair": f'{parsed["from_symbol"]}/{parsed["to_symbol"]}',
            "path": path,
            "route": route,
        }

    def health():
        ready = (time.time() - started_at) > 0.5
        return jsonify(
            ok=True,
            status="ok",
            service="dex",
            ready=ready,
            price_source="static",
            execution_enabled=False,
            endpoints=["/health", "/pairs", "/quote", "/swap"],
        )

    def pairs():
        symbols = sorted(SUPPORTED_DECIMALS)
        return jsonify(
            ok=True,
            status="ok",
            service="dex",
            symbols=symbols,
            bridge_asset="WETH",
            stable_assets=sorted(STABLES),
            request_formats={
                "raw": {"field": "amount", "example": 1000000},
                "display": {"field": "amount_in", "example": "1.5"},
            },
        )

    def quote():
        payload = request.get_json(silent=True) or {}
        try:
            parsed = parse_request(payload)
        except ValueError as exc:
            return json_error(str(exc))
        return jsonify(build_quote(parsed))

    def swap():
        payload = request.get_json(silent=True) or {}
        try:
            parsed = parse_request(payload)
        except ValueError as exc:
            return json_error(str(exc))
        response = build_quote(parsed)
        response["submit_status"] = "preview_only"
        return jsonify(response)

    register_dual_route("/health", "health", health, ["GET"])
    register_dual_route("/pairs", "pairs", pairs, ["GET"])
    register_dual_route("/quote", "quote", quote, ["POST"])
    register_dual_route("/swap", "swap", swap, ["POST"])

    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
