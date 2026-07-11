#!/usr/bin/env python3
"""Simple pull-style metrics aggregator.
Scrapes JSON health endpoints (expects {'status':'ok'}) and exposes Prometheus text format.
"""
import asyncio
import os
import time
from typing import Any

import aiohttp
from aiohttp import web

PORT = int(os.environ.get("METRICS_PORT", "9100"))


def parse_targets(raw: str) -> list[dict[str, str]]:
    targets: list[dict[str, str]] = []
    for item in str(raw or "").split(","):
        part = item.strip()
        if not part:
            continue
        if "|" not in part:
            continue
        service, target = part.split("|", 1)
        service = service.strip()
        target = target.strip()
        if not target.startswith(("http://", "https://")):
            target = f"http://{target}"
        targets.append({"service": service, "target": target})
    return targets


async def fetch(session: aiohttp.ClientSession, target: dict[str, str]) -> dict[str, Any]:
    start = time.time()
    url = target["target"]
    try:
        async with session.get(url, timeout=5) as resp:
            body = await resp.text()
            status_code = resp.status
            ok = status_code == 200
    except Exception:
        body = ""
        status_code = 0
        ok = False
    duration = time.time() - start
    return {
        "service": target.get("service", ""),
        "target": url,
        "ok": ok,
        "status_code": status_code,
        "duration_seconds": duration,
        "body": body,
    }


def render_metrics(results: list[dict[str, Any]]) -> str:
    lines = ["# HELP service_up Service health (1=up)", "# TYPE service_up gauge"]
    lines.append("# HELP service_http_status HTTP status code")
    lines.append("# TYPE service_http_status gauge")
    lines.append("# HELP service_scrape_duration_seconds Health scrape latency")
    lines.append("# TYPE service_scrape_duration_seconds gauge")
    for item in results:
        service = item.get("service", "")
        target = item.get("target", "")
        ok = 1 if item.get("ok") else 0
        status_code = item.get("status_code", 0)
        duration = float(item.get("duration_seconds", 0.0))
        lines.append(f'service_up{{service="{service}",target="{target}"}} {ok}')
        lines.append(f'service_http_status{{service="{service}",target="{target}"}} {status_code}')
        lines.append(f'service_scrape_duration_seconds{{service="{service}",target="{target}"}} {duration:.4f}')
    return "\n".join(lines) + "\n"


async def metrics_handler(_):
    targets = parse_targets(os.environ.get("TARGETS", ""))
    async with aiohttp.ClientSession() as session:
        results = await asyncio.gather(*(fetch(session, target) for target in targets), return_exceptions=True)
    normalized: list[dict[str, Any]] = []
    for target, result in zip(targets, results):
        if isinstance(result, Exception):
            normalized.append({"service": target.get("service", ""), "target": target["target"], "ok": False, "status_code": 0, "duration_seconds": 0.0})
        else:
            normalized.append(result)
    return web.Response(text=render_metrics(normalized), content_type="text/plain")


app = web.Application()
app.router.add_get("/metrics", metrics_handler)

if __name__ == "__main__":
    web.run_app(app, port=PORT)
