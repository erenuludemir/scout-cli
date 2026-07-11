from __future__ import annotations

import json
import os
import subprocess
import time
from pathlib import Path
from typing import Any

from managerai.reporter import emit_report
from managerai.shutdown_hook import install_shutdown_handlers, is_shutdown_requested
from managerai.state import ResidentState, utcnow_iso


ROOT = Path(os.environ.get("MANAGERAI_REPO_ROOT", "/repo")).resolve()
QAI_MANAGER = Path(os.environ.get("MANAGERAI_QAI_MANAGER", str(ROOT / "ops" / "qai_manager_ai.sh"))).resolve()
LOOP_INTERVAL = int(os.environ.get("MANAGERAI_LOOP_INTERVAL_SECS", "600"))
APPLY_ON_CRITICAL = os.environ.get("MANAGERAI_APPLY_ON_CRITICAL", "1").lower() in {"1", "true", "yes"}
APPLY_ON_HIGH = os.environ.get("MANAGERAI_APPLY_ON_HIGH", "0").lower() in {"1", "true", "yes"}
LOG_LINES = int(os.environ.get("MANAGERAI_LOG_LINES", "80"))
COOLDOWN = int(os.environ.get("MANAGERAI_COOLDOWN_SECS", "900"))
MAX_RESTART_COUNT = int(os.environ.get("MANAGERAI_MAX_RESTART_COUNT", "6"))
DELAY_SECS = float(os.environ.get("MANAGERAI_DELAY_SECS", "2"))
COMMAND_TIMEOUT = int(
    os.environ.get(
        "MANAGERAI_CMD_TIMEOUT_SECS",
        os.environ.get("MANAGERAI_COMMAND_TIMEOUT_SECS", "420"),
    )
)
COMPOSE_FILES_RAW = os.environ.get(
    "MANAGERAI_COMPOSE_FILES",
    "compose.master.yml,compose.yml,compose.override.yml,docker-compose.base.yml,docker-compose.override.yml,compose.managerai.yml",
)
EXCLUDE_SERVICES_RAW = os.environ.get("MANAGERAI_EXCLUDE_SERVICES", "managerai-broker,managerai-guard")
EXCLUDE_SERVICES = {item.strip() for item in EXCLUDE_SERVICES_RAW.split(",") if item.strip()}


def compose_args() -> list[str]:
    args: list[str] = []
    for raw_part in COMPOSE_FILES_RAW.split(","):
        part = raw_part.strip()
        if not part:
            continue
        path = (ROOT / part).resolve()
        if path.exists():
            args.extend(["--compose-file", str(path)])
    return args


def run_cmd(args: list[str]) -> dict[str, Any]:
    try:
        proc = subprocess.run(
            args,
            cwd=str(ROOT),
            capture_output=True,
            text=True,
            env=os.environ.copy(),
            timeout=COMMAND_TIMEOUT,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        raise RuntimeError(f"Command {args!r} timed out after {COMMAND_TIMEOUT} seconds") from exc
    stdout = (proc.stdout or "").strip()
    stderr = (proc.stderr or "").strip()
    if proc.returncode != 0:
        raise RuntimeError(f"returncode={proc.returncode} stderr={stderr} stdout={stdout[:500]}")
    if not stdout:
        return {"status": "ok"}
    try:
        payload = json.loads(stdout)
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"invalid-json stdout={stdout[:1000]}") from exc
    return filtered_payload(payload)


def _keep_service(name: str) -> bool:
    return bool(name) and name not in EXCLUDE_SERVICES


def filtered_payload(payload: dict[str, Any]) -> dict[str, Any]:
    result = dict(payload)

    services = payload.get("services")
    if isinstance(services, list):
        kept_services = [item for item in services if _keep_service(str(item.get("service", "")).strip())]
        result["services"] = kept_services
        result["service_count"] = len(kept_services)
        statuses = {str(item.get("status", "unknown")) for item in kept_services}
        if not kept_services:
            result["status"] = "ok"
        elif "degraded" in statuses:
            result["status"] = "degraded"
        elif "missing" in statuses:
            result["status"] = "missing"
        elif statuses == {"ok"}:
            result["status"] = "ok"
        elif statuses == {"unknown"}:
            result["status"] = "unknown"

    actions = payload.get("actions")
    if isinstance(actions, list):
        result["actions"] = [item for item in actions if _keep_service(str(item.get("service", "")).strip())]

    return result


def diagnose() -> dict[str, Any]:
    cmd = [
        "bash",
        str(QAI_MANAGER),
        "diagnose",
        "--json",
        "--log-lines",
        str(LOG_LINES),
        "--cooldown-secs",
        str(COOLDOWN),
        *compose_args(),
    ]
    return run_cmd(cmd)


def choose_apply(diagnose_payload: dict[str, Any]) -> bool:
    services = diagnose_payload.get("services", [])
    if not services:
        return False
    critical = any(item.get("risk_level") == "critical" for item in services)
    high = any(item.get("risk_level") == "high" for item in services)
    actionable = any(item.get("recommended_action") in {"restart", "rolling-restart"} for item in services)
    if not actionable:
        return False
    if critical and APPLY_ON_CRITICAL:
        return True
    if high and APPLY_ON_HIGH:
        return True
    return False


def autopilot(*, apply: bool, service: str | None = None) -> dict[str, Any]:
    cmd = [
        "bash",
        str(QAI_MANAGER),
        "autopilot",
        "--json",
        "--log-lines",
        str(LOG_LINES),
        "--cooldown-secs",
        str(COOLDOWN),
        "--max-restart-count",
        str(MAX_RESTART_COUNT),
        "--delay-secs",
        str(DELAY_SECS),
        *compose_args(),
    ]
    if apply:
        cmd.insert(3, "--apply")
    if service:
        cmd.extend(["--service", service])
    return run_cmd(cmd)


def on_shutdown(reason: str) -> None:
    emit_report(
        "shutdown",
        {
            "status": "shutdown",
            "service_count": 0,
            "services": [],
            "reason": reason,
            "timestamp": utcnow_iso(),
        },
    )


def main() -> int:
    install_shutdown_handlers(on_shutdown)
    state = ResidentState.from_disk()
    state.mode = "resident"
    state.compose_files = [
        str((ROOT / part.strip()).resolve())
        for part in COMPOSE_FILES_RAW.split(",")
        if part.strip() and (ROOT / part.strip()).exists()
    ]
    state.save()
    state.heartbeat({"startup": True, "cmd_timeout_secs": COMMAND_TIMEOUT})
    emit_report(
        "startup",
        {
            "status": "ok",
            "service_count": 0,
            "services": [],
            "compose_files": state.compose_files,
            "cmd_timeout_secs": COMMAND_TIMEOUT,
        },
    )

    while not is_shutdown_requested():
        state.cycle += 1
        try:
            diagnose_payload = diagnose()
            state.last_diagnose_status = str(diagnose_payload.get("status", "unknown"))
            report_info = emit_report("diagnose", diagnose_payload)
            apply = choose_apply(diagnose_payload)
            autopilot_payload = autopilot(apply=apply)
            state.last_autopilot_mode = str(autopilot_payload.get("mode", "dry-run"))
            state.last_autopilot_actions = len(autopilot_payload.get("actions", []))
            emit_report("autopilot", autopilot_payload)
            state.last_error = ""
            state.note_action(
                {
                    "timestamp": utcnow_iso(),
                    "cycle": state.cycle,
                    "diagnose_status": state.last_diagnose_status,
                    "autopilot_mode": state.last_autopilot_mode,
                    "autopilot_actions": state.last_autopilot_actions,
                    "report_paths": report_info.get("paths", {}),
                    "cmd_timeout_secs": COMMAND_TIMEOUT,
                }
            )
        except Exception as exc:
            state.last_error = str(exc)
            state.note_action(
                {
                    "timestamp": utcnow_iso(),
                    "cycle": state.cycle,
                    "error": str(exc),
                    "cmd_timeout_secs": COMMAND_TIMEOUT,
                }
            )
            emit_report(
                "error",
                {
                    "status": "error",
                    "service_count": 0,
                    "services": [],
                    "error": str(exc),
                    "timestamp": utcnow_iso(),
                    "cmd_timeout_secs": COMMAND_TIMEOUT,
                },
            )
        state.save()
        state.heartbeat({"sleep_secs": LOOP_INTERVAL, "cmd_timeout_secs": COMMAND_TIMEOUT})
        slept = 0
        while slept < LOOP_INTERVAL and not is_shutdown_requested():
            time.sleep(1)
            slept += 1

    state.mode = "stopped"
    state.save()
    state.heartbeat({"stopped": True, "cmd_timeout_secs": COMMAND_TIMEOUT})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
