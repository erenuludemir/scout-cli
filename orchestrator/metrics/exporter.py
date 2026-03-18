#!/usr/bin/env python3
"""Simple pull-style metrics aggregator.
Scrapes JSON health endpoints (expects {'status':'ok'}) and exposes Prometheus text format.
"""
import os
import asyncio
import aiohttp
import time
from aiohttp import web

PORT = int(os.environ.get('METRICS_PORT','9100'))
TARGETS = [t.strip() for t in os.environ.get('TARGETS','').split(',') if t.strip()]

async def fetch(session, target):
    url = f"http://{target}"
    start = time.time()
    try:
        async with session.get(url, timeout=5) as resp:
            await resp.text()
            ok = resp.status == 200
    except Exception:
        ok = False
    dur = time.time()-start
    return ok, dur

async def metrics_handler(_):
    async with aiohttp.ClientSession() as session:
        results = await asyncio.gather(*(fetch(session, t) for t in TARGETS), return_exceptions=True)
    lines = ["# HELP service_up Service health (1=up)\n# TYPE service_up gauge"]
    lines.append("# HELP service_scrape_duration_seconds Health scrape latency\n# TYPE service_scrape_duration_seconds gauge")
    for target, res in zip(TARGETS, results):
        if isinstance(res, Exception):
            ok, dur = 0, 0
        else:
            ok, dur = (1 if res[0] else 0), res[1]
        lines.append(f"service_up{{target=\"{target}\"}} {ok}")
        lines.append(f"service_scrape_duration_seconds{{target=\"{target}\"}} {dur:.4f}")
    return web.Response(text="\n".join(lines)+"\n", content_type='text/plain')

app = web.Application()
app.router.add_get('/metrics', metrics_handler)

if __name__ == '__main__':
    web.run_app(app, port=PORT)
