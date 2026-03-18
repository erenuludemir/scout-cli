#!/usr/bin/env bash
set -euo pipefail

python3 - <<'PY'
from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request


def request(name: str, method: str, url: str, payload: dict | None = None) -> dict:
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=20) as response:
            body = response.read().decode("utf-8", errors="replace")
            return {"name": name, "status_code": response.status, "body": body}
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        return {"name": name, "status_code": exc.code, "body": body}
    except Exception as exc:  # pragma: no cover - smoke only
        return {"name": name, "status_code": 0, "body": str(exc)}


checks = [
    ("gateway_health", "GET", "http://127.0.0.1:5003/health", None),
    ("gateway_root", "GET", "http://127.0.0.1:5003/", None),
    ("dex_pairs", "GET", "http://127.0.0.1:5003/dex/pairs", None),
    ("dex_quote", "POST", "http://127.0.0.1:5003/dex/quote", {"from": "USDT", "to": "WETH", "amount": 1000000}),
    (
        "dex_swap",
        "POST",
        "http://127.0.0.1:5003/dex/swap",
        {"from_token": "ETH", "to_token": "USDT", "amount_in": 1.5, "slippage_bps": 75},
    ),
    ("usdt_health", "GET", "http://127.0.0.1:5003/usdt/health", None),
    (
        "usdt_balance",
        "POST",
        "http://127.0.0.1:5003/usdt/balance",
        {"address": "0x71c7656ec7ab88b098defb751b7401b5f6d8976f"},
    ),
    (
        "usdt_estimate",
        "POST",
        "http://127.0.0.1:5003/usdt/estimate",
        {"recipient": "0x0000000000000000000000000000000000000001", "amount": 1},
    ),
    (
        "usdt_transfer",
        "POST",
        "http://127.0.0.1:5003/usdt/transfer",
        {"recipient": "0x0000000000000000000000000000000000000001", "amount": 1},
    ),
    ("gli_root", "GET", "http://127.0.0.1:5006/", None),
    (
        "gli_estimate",
        "POST",
        "http://127.0.0.1:5006/estimate",
        {"recipient": "0x0000000000000000000000000000000000000001", "amount": 1},
    ),
    (
        "gli_approve",
        "POST",
        "http://127.0.0.1:5006/approve",
        {"spender": "0x0000000000000000000000000000000000000001", "amount": "unlimited"},
    ),
    (
        "gli_transfer",
        "POST",
        "http://127.0.0.1:5006/transfer",
        {"recipient": "0x0000000000000000000000000000000000000001", "amount": 1},
    ),
    ("gli_mainnet_root", "GET", "http://127.0.0.1:5002/", None),
    ("gli_sepolia_root", "GET", "http://127.0.0.1:5004/", None),
    ("usdt_v2_root", "GET", "http://127.0.0.1:5005/", None),
    ("usdt_v2_health", "GET", "http://127.0.0.1:5005/health", None),
]


def parse_json(body: str) -> dict:
    try:
        return json.loads(body)
    except Exception:
        return {}


def is_ok(result: dict) -> tuple[bool, str]:
    name = result["name"]
    code = result["status_code"]
    body = result["body"]
    payload = parse_json(body)
    status = str(payload.get("status", "")).lower()

    if name in {"gateway_health", "gateway_root", "dex_pairs", "dex_quote", "dex_swap", "gli_root", "gli_estimate", "gli_approve", "gli_mainnet_root", "gli_sepolia_root", "usdt_v2_root", "usdt_v2_health"}:
        return code == 200, f"expected 200 got {code}"

    if name == "usdt_health":
        return code == 200 and payload.get("ok") is True, f"health code={code}"

    if name == "usdt_balance":
        ok = (code == 200 and status == "ok") or (code == 503 and "preview mode" in body.lower())
        return ok, f"balance code={code}"

    if name in {"usdt_estimate", "usdt_transfer"}:
        ok = (code == 200 and status in {"ok", "preview"}) or (code == 503 and "preview mode" in body.lower())
        return ok, f"usdt action code={code} status={status}"

    if name == "gli_transfer":
        ok = (code == 200 and status in {"preview", "success", "reverted"}) or (code == 400 and "insufficient usdt balance" in body.lower())
        return ok, f"gli transfer code={code} status={status}"

    return False, f"unclassified check code={code}"


results = [request(*item) for item in checks]
problems = []
summary = []
for item in results:
    ok, note = is_ok(item)
    payload = parse_json(item["body"])
    summary.append(
        {
            "name": item["name"],
            "ok": ok,
            "status_code": item["status_code"],
            "status": payload.get("status"),
            "note": note,
            "body_preview": item["body"][:240],
        }
    )
    if not ok:
        problems.append(f'{item["name"]}:{note}')

report = {"ok": not problems, "checks": summary, "problems": problems}
print(json.dumps(report, ensure_ascii=False, indent=2))
if problems:
    sys.exit(1)
PY
