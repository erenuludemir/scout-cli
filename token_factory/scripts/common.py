from __future__ import annotations

import csv
import json
import time
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

from token_factory.config import TokenFactoryConfig


def load_config() -> TokenFactoryConfig:
    root = Path(__file__).resolve().parents[2]
    env_path = root / ".env.token_factory"
    if env_path.exists():
        load_dotenv(env_path)
    return TokenFactoryConfig(root=root)


def read_distribution_csv(path: str | Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with Path(path).open("r", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            address = str(row.get("address", "")).strip()
            try:
                amount = int(str(row.get("amount", "0")).strip())
            except Exception:
                amount = 0
            if not address or amount <= 0:
                continue
            rows.append({"address": address, "amount": amount})
    return rows


def manifest_write(path: str | Path, payload: dict[str, Any]) -> None:
    out_path = Path(path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def utc_ts() -> int:
    return int(time.time())
