from __future__ import annotations

import json
import re
from collections import deque
from pathlib import Path
from typing import Any

from fastapi import FastAPI, Query
from pydantic import BaseModel, Field

from managerai.state import (
    BROKER_QUEUE_DIR,
    LAST_REPORT_FILE,
    STATE_FILE,
    append_jsonl,
    atomic_write_json,
    load_json,
    utcnow_iso,
)


app = FastAPI(title="ManagerAI Broker", version="1.0.0")
TOPICS_DIR = BROKER_QUEUE_DIR / "topics"


class PublishRequest(BaseModel):
    topic: str = Field(min_length=1)
    payload: dict[str, Any] = Field(default_factory=dict)


def ensure_topics_dir() -> Path:
    TOPICS_DIR.mkdir(parents=True, exist_ok=True)
    return TOPICS_DIR


def _topic_file(topic: str) -> Path:
    safe = re.sub(r"[^A-Za-z0-9._-]+", "_", topic).strip("._") or "untitled"
    return ensure_topics_dir() / f"{safe}.jsonl"


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "timestamp": utcnow_iso(),
        "queue_dir": str(TOPICS_DIR),
        "last_report": load_json(LAST_REPORT_FILE, {}),
        "resident_state": load_json(STATE_FILE, {}),
    }


@app.get("/healthz")
def healthz() -> dict[str, Any]:
    return {"status": "ok", "service": "managerai-broker"}


@app.post("/publish")
def publish(req: PublishRequest) -> dict[str, Any]:
    event = {"timestamp": utcnow_iso(), "topic": req.topic, "payload": req.payload}
    path = _topic_file(req.topic)
    append_jsonl(path, event)
    latest_path = TOPICS_DIR / "latest.json"
    atomic_write_json(latest_path, event)
    return {"status": "ok", "topic": req.topic, "path": str(path)}


@app.get("/topics")
def topics(limit: int = Query(default=50, ge=1, le=500)) -> dict[str, Any]:
    files = sorted(ensure_topics_dir().glob("*.jsonl"))
    recent = [str(path) for path in files[-limit:]]
    return {"status": "ok", "topics": recent, "topic_count": len(files)}


@app.get("/topics/latest")
def latest() -> dict[str, Any]:
    latest_path = ensure_topics_dir() / "latest.json"
    return {"status": "ok", "latest": load_json(latest_path, {})}


@app.get("/topics/{topic_name}")
def topic_events(topic_name: str, limit: int = Query(default=20, ge=1, le=200)) -> dict[str, Any]:
    path = _topic_file(topic_name.removesuffix(".jsonl"))
    if not path.exists():
        return {"status": "ok", "topic": topic_name, "events": []}
    events: deque[dict[str, Any]] = deque(maxlen=limit)
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return {"status": "ok", "topic": topic_name, "events": list(events)}
