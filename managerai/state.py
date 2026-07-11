from __future__ import annotations

import json
import os
import socket
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


BASE_DIR = Path(os.environ.get("MANAGERAI_BASE_DIR", "/repo")).resolve()
STATE_DIR = Path(os.environ.get("MANAGERAI_STATE_DIR", str(BASE_DIR / "_state" / "managerai"))).resolve()
REPORT_DIR = Path(os.environ.get("MANAGERAI_REPORT_DIR", str(BASE_DIR / "_reports" / "managerai"))).resolve()
LOG_DIR = Path(os.environ.get("MANAGERAI_LOG_DIR", str(BASE_DIR / "_logs" / "managerai"))).resolve()
BROKER_QUEUE_DIR = Path(
    os.environ.get("MANAGERAI_BROKER_QUEUE_DIR", str(STATE_DIR / "queue"))
).resolve()

for path in (STATE_DIR, REPORT_DIR, LOG_DIR, BROKER_QUEUE_DIR):
    path.mkdir(parents=True, exist_ok=True)

STATE_FILE = STATE_DIR / "resident_state.json"
HEARTBEAT_FILE = STATE_DIR / "heartbeat.json"
LAST_REPORT_FILE = STATE_DIR / "last_report.json"
ACTION_LOG = LOG_DIR / "resident_actions.jsonl"


def utcnow_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8", dir=str(path.parent)) as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
        temp_name = handle.name
    os.replace(temp_name, path)


def load_json(path: Path, default: Any = None) -> Any:
    if not path.exists():
        return {} if default is None else default
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {} if default is None else default


def append_jsonl(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False) + "\n")


@dataclass
class ResidentState:
    started_at: str = field(default_factory=utcnow_iso)
    updated_at: str = field(default_factory=utcnow_iso)
    host: str = field(default_factory=socket.gethostname)
    pid: int = field(default_factory=os.getpid)
    cycle: int = 0
    mode: str = "resident"
    last_diagnose_status: str = "unknown"
    last_autopilot_mode: str = "dry-run"
    last_autopilot_actions: int = 0
    last_error: str = ""
    compose_files: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "started_at": self.started_at,
            "updated_at": self.updated_at,
            "host": self.host,
            "pid": self.pid,
            "cycle": self.cycle,
            "mode": self.mode,
            "last_diagnose_status": self.last_diagnose_status,
            "last_autopilot_mode": self.last_autopilot_mode,
            "last_autopilot_actions": self.last_autopilot_actions,
            "last_error": self.last_error,
            "compose_files": self.compose_files,
        }

    @classmethod
    def from_disk(cls) -> "ResidentState":
        data = load_json(STATE_FILE, {})
        state = cls()
        for key, value in data.items():
            if hasattr(state, key):
                setattr(state, key, value)
        state.pid = os.getpid()
        state.updated_at = utcnow_iso()
        return state

    def save(self) -> None:
        self.updated_at = utcnow_iso()
        atomic_write_json(STATE_FILE, self.to_dict())

    def heartbeat(self, extra: dict[str, Any] | None = None) -> None:
        payload = {
            "timestamp": utcnow_iso(),
            "host": self.host,
            "pid": os.getpid(),
            "cycle": self.cycle,
            "mode": self.mode,
            "last_diagnose_status": self.last_diagnose_status,
            "last_autopilot_mode": self.last_autopilot_mode,
            "last_autopilot_actions": self.last_autopilot_actions,
        }
        if extra:
            payload.update(extra)
        atomic_write_json(HEARTBEAT_FILE, payload)

    def note_action(self, payload: dict[str, Any]) -> None:
        append_jsonl(ACTION_LOG, payload)
