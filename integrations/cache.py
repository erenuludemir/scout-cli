"""Lightweight optional Redis cache helpers.

Behavior:
* No-op if REDIS_URL unset or redis import fails.
* Silently ignores network/serialization errors.
* Provides simple JSON (de)serializing get/set with TTL.
"""
from __future__ import annotations

from typing import Any, Optional
import json
import os
import time

_redis_client = None  # type: ignore
_mem_cache: dict[str, tuple[float, Any, int]] = {}


def _init() -> None:
    """Lazy initialize redis client if REDIS_URL present."""
    global _redis_client  # noqa: PLW0603
    if _redis_client is not None:
        return
    url = os.getenv("REDIS_URL")
    if not url:
        return
    try:  # pragma: no cover - network path
        import redis  # type: ignore
        _redis_client = redis.Redis.from_url(url, socket_timeout=0.5)
    except Exception:
        _redis_client = None


def cache_get(key: str) -> Optional[Any]:
    _init()
    if _redis_client is not None:
        try:  # pragma: no cover - network
            raw = _redis_client.get(key)
            if raw is None:
                return None
            return json.loads(raw)
        except Exception:
            return None
    # Fallback to in-process cache
    ent = _mem_cache.get(key)
    if not ent:
        return None
    ts, val, ttl = ent
    if ttl > 0 and (time.time() - ts) > ttl:
        _mem_cache.pop(key, None)
        return None
    return val


def cache_set(key: str, value: Any, ttl: int) -> None:
    _init()
    if _redis_client is not None:
        try:  # pragma: no cover - network
            payload = json.dumps({"v": value, "ts": int(time.time())})
            if ttl > 0:
                _redis_client.setex(key, ttl, payload)
            else:
                _redis_client.set(key, payload)
        except Exception:
            pass
    else:  # in-process fallback
        _mem_cache[key] = (time.time(), {"v": value}, ttl)


def cache_get_value(key: str) -> Optional[Any]:
    data = cache_get(key)
    if isinstance(data, dict):
        return data.get("v")
    return None


def cache_clear() -> None:
    _mem_cache.clear()
