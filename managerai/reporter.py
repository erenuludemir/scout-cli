from __future__ import annotations

import json
import os
from typing import Any

import requests

from managerai.state import LAST_REPORT_FILE, REPORT_DIR, atomic_write_json, utcnow_iso


BROKER_URL = os.environ.get("MANAGERAI_BROKER_URL", "http://127.0.0.1:8787")
BROKER_FALLBACK_URL = os.environ.get("MANAGERAI_BROKER_FALLBACK_URL", "http://127.0.0.1:8012")


def _service_rows(services: list[dict[str, Any]]) -> str:
    lines = ["| service | status | score | risk | action |", "|---|---:|---:|---|---|"]
    for item in services:
        lines.append(
            f"| {item.get('service', '-')} | {item.get('status', '-')} | "
            f"{item.get('quantum_score', '-')} | {item.get('risk_level', '-')} | "
            f"{item.get('recommended_action', '-')} |"
        )
    return "\n".join(lines)


def build_report(kind: str, payload: dict[str, Any]) -> dict[str, Any]:
    timestamp = utcnow_iso()
    services = payload.get("services", [])
    markdown = [
        f"# ManagerAI {kind} Report",
        "",
        f"- timestamp: {timestamp}",
        f"- status: {payload.get('status', 'unknown')}",
        f"- service_count: {payload.get('service_count', len(services))}",
        "",
        _service_rows(services) if services else "_service yok_",
        "",
        "## Raw JSON",
        "",
        "```json",
        json.dumps(payload, ensure_ascii=False, indent=2),
        "```",
        "",
    ]
    return {
        "timestamp": timestamp,
        "kind": kind,
        "status": payload.get("status", "unknown"),
        "service_count": payload.get("service_count", len(services)),
        "services": services,
        "markdown": "\n".join(markdown),
        "payload": payload,
    }


def persist_report(report: dict[str, Any]) -> dict[str, str]:
    stamp = report["timestamp"].replace(":", "").replace("-", "")
    md_path = REPORT_DIR / f"{report['kind']}_{stamp}.md"
    json_path = REPORT_DIR / f"{report['kind']}_{stamp}.json"
    md_path.write_text(report["markdown"], encoding="utf-8")
    json_path.write_text(
        json.dumps(report["payload"], ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    atomic_write_json(
        LAST_REPORT_FILE,
        {
            "timestamp": report["timestamp"],
            "kind": report["kind"],
            "status": report["status"],
            "markdown_path": str(md_path),
            "json_path": str(json_path),
        },
    )
    return {"markdown_path": str(md_path), "json_path": str(json_path)}


def broker_publish(topic: str, payload: dict[str, Any]) -> dict[str, Any]:
    targets = [url for url in (BROKER_URL, BROKER_FALLBACK_URL) if url]
    if not targets:
        return {"ok": False, "error": "broker-url-missing"}
    seen: set[str] = set()
    last_error = "broker-publish-failed"
    for target in targets:
        normalized = target.rstrip("/")
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        try:
            response = requests.post(
                f"{normalized}/publish",
                json={"topic": topic, "payload": payload},
                timeout=10,
            )
            return {
                "ok": response.ok,
                "target": normalized,
                "status_code": response.status_code,
                "body": response.text[:500],
            }
        except Exception as exc:
            last_error = str(exc)
    return {"ok": False, "error": last_error, "targets": sorted(seen)}


def emit_report(kind: str, payload: dict[str, Any]) -> dict[str, Any]:
    report = build_report(kind, payload)
    paths = persist_report(report)
    broker = broker_publish(f"managerai.{kind}", report)
    return {
        "ok": True,
        "timestamp": report["timestamp"],
        "kind": kind,
        "status": report["status"],
        "paths": paths,
        "broker": broker,
    }
