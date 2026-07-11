from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

try:
    import yaml
except ModuleNotFoundError:  # pragma: no cover - exercised by CLI subprocess tests
    yaml = None


@dataclass
class ServiceRecord:
    service: str
    container_name: str
    compose_file: str
    has_healthcheck: bool
    healthcheck_target: str = ""
    healthcheck_target_path: str = ""


REPO_ROOT = Path(__file__).resolve().parent.parent
DOCKER_BIN = os.environ.get("SUPERVIZOR_DOCKER_BIN", "docker")
DOCKER_TIMEOUT_SECS = max(
    1,
    int(os.environ.get("SUPERVIZOR_DOCKER_TIMEOUT_SECS") or os.environ.get("MANAGERAI_CMD_TIMEOUT_SECS") or "5"),
)
DEFAULT_DELAY = float(os.environ.get("SUPERVIZOR_ROLLING_DELAY_SECS", "2"))
DEFAULT_DRY_RUN = os.environ.get("SUPERVIZOR_DRY_RUN", "0") == "1"
DEFAULT_LOG_LINES = int(os.environ.get("SUPERVIZOR_LOG_LINES", "120"))
DEFAULT_COOLDOWN_SECS = int(os.environ.get("SUPERVIZOR_ACTION_COOLDOWN_SECS", "900"))
DEFAULT_MAX_RESTART_COUNT = int(os.environ.get("SUPERVIZOR_MAX_RESTART_COUNT", "6"))
DEFAULT_HISTORY_LIMIT = int(os.environ.get("SUPERVIZOR_HISTORY_LIMIT", "20"))
HISTORY_FILE = Path(
    os.environ.get(
        "SUPERVIZOR_HISTORY_FILE",
        str(REPO_ROOT / "_logs" / "manager_ai" / "history.jsonl"),
    )
)

LOG_PATTERNS: dict[str, re.Pattern[str]] = {
    "traceback": re.compile(r"traceback", re.IGNORECASE),
    "exception": re.compile(r"\b(exception|fatal|panic)\b", re.IGNORECASE),
    "oom": re.compile(r"(oomkilled|out of memory|killed process)", re.IGNORECASE),
    "gateway": re.compile(r"(502 bad gateway|connect\(\) failed|upstream)", re.IGNORECASE),
    "restart_loop": re.compile(r"(crashloop|back[- ]off|restarting)", re.IGNORECASE),
    "docs_probe": re.compile(r'"(?:GET|HEAD) /docs(?:[ ?\'"]|$)', re.IGNORECASE),
    "openapi_probe": re.compile(r'"(?:GET|HEAD) /openapi\.json(?:[ ?\'"]|$)', re.IGNORECASE),
    "insecure_admin_api": re.compile(r"insecure admin api listener", re.IGNORECASE),
    "reactor_stall": re.compile(r"reactor stalled", re.IGNORECASE),
}

ACTIONABLE_DECISIONS = {"restart", "rolling-restart"}

SIGNAL_SCORE_WEIGHTS: dict[str, int] = {
    "traceback": 5,
    "exception": 5,
    "oom": 8,
    "gateway": 3,
    "restart_loop": 5,
    "docs_probe": 1,
    "openapi_probe": 1,
    "insecure_admin_api": 6,
    "reactor_stall": 4,
}

SIGNAL_SCORE_CAPS: dict[str, int] = {
    "traceback": 20,
    "exception": 20,
    "oom": 20,
    "gateway": 12,
    "restart_loop": 20,
    "docs_probe": 8,
    "openapi_probe": 6,
    "insecure_admin_api": 12,
    "reactor_stall": 12,
}


def utcnow_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def split_compose_spec(raw: str) -> list[str]:
    return [part.strip() for part in re.split(r"[:,]", raw) if part.strip()]


def configured_service_allowlist() -> set[str]:
    raw = os.environ.get("SUPERVIZOR_SERVICE_ALLOWLIST", "").strip()
    if not raw:
        return set()
    return set(split_compose_spec(raw))


def _resolve_compose_file_refs(parts: list[str], *, fail_on_missing: bool) -> list[Path]:
    files: list[Path] = []
    missing: list[str] = []
    for part in parts:
        path = Path(part)
        if not path.is_absolute():
            path = (REPO_ROOT / path).resolve()
        if path.exists():
            files.append(path)
        elif fail_on_missing:
            missing.append(str(path))
    if missing:
        raise SystemExit(f"compose file(s) not found: {', '.join(missing)}")
    return files


def default_compose_files() -> list[Path]:
    compose = REPO_ROOT / "compose.yml"
    override = REPO_ROOT / "compose.override.yml"
    if compose.exists():
        try:
            compose_text = compose.read_text(errors="replace")
        except OSError:
            compose_text = ""
        if all(marker in compose_text for marker in ("gli-mainnet:", "quantumai-usdt-v2:", "redis:")):
            files = [compose]
            if override.exists():
                files.append(override)
            return files

    candidates = [
        compose,
        override,
        REPO_ROOT / "compose.master.yml",
        REPO_ROOT / "stack" / "docker-compose.yml",
        REPO_ROOT / "docker-compose.yml",
        REPO_ROOT / "docker-compose.override.yml",
        REPO_ROOT / "docker-compose.base.yml",
        REPO_ROOT / "docker-compose.usdt.yml",
    ]
    return [path for path in candidates if path.exists()]


def configured_compose_files(explicit_parts: list[str] | None = None) -> list[Path]:
    files: list[Path] = []
    if explicit_parts:
        files = _resolve_compose_file_refs(explicit_parts, fail_on_missing=True)
    if not files:
        raw = os.environ.get("SUPERVIZOR_COMPOSE_FILES", "").strip()
        if raw:
            files = _resolve_compose_file_refs(split_compose_spec(raw), fail_on_missing=False)
    if not files:
        files = default_compose_files()
    unique: list[Path] = []
    seen: set[str] = set()
    for path in files:
        resolved = str(path.resolve())
        if resolved in seen:
            continue
        seen.add(resolved)
        unique.append(path.resolve())
    return unique


def _strip_inline_comment(line: str) -> str:
    in_single = False
    in_double = False
    escaped = False
    result: list[str] = []
    for ch in line:
        if escaped:
            result.append(ch)
            escaped = False
            continue
        if ch == "\\":
            result.append(ch)
            escaped = True
            continue
        if ch == "'" and not in_double:
            in_single = not in_single
        elif ch == '"' and not in_single:
            in_double = not in_double
        elif ch == "#" and not in_single and not in_double:
            break
        result.append(ch)
    return "".join(result).rstrip()


def _parse_scalar(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return value[1:-1]
    return value


def _fallback_compose_load(text: str) -> dict[str, Any]:
    services: dict[str, dict[str, Any]] = {}
    in_services = False
    services_indent = 0
    current_service: str | None = None
    service_indent = 0

    for raw_line in text.splitlines():
        line = _strip_inline_comment(raw_line.rstrip())
        if not line.strip():
            continue

        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()

        if not in_services:
            if stripped == "services:":
                in_services = True
                services_indent = indent
            continue

        if indent <= services_indent:
            current_service = None
            if stripped.endswith(":") and stripped != "services:":
                in_services = False
            continue

        if indent == services_indent + 2 and stripped.endswith(":") and not stripped.startswith("- "):
            current_service = stripped[:-1].strip().strip("'\"")
            services[current_service] = {}
            service_indent = indent
            continue

        if current_service is None or indent <= service_indent:
            continue

        if indent == service_indent + 2 and ":" in stripped:
            key, value = stripped.split(":", 1)
            key = key.strip()
            value = value.strip()
            if key == "container_name":
                services[current_service]["container_name"] = _parse_scalar(value)
            elif key == "healthcheck":
                services[current_service]["healthcheck"] = {} if not value else value

    return {"services": services}


def load_compose_data(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    if yaml is not None:
        loaded = yaml.safe_load(text) or {}
        if isinstance(loaded, dict):
            return loaded
        return {}
    return _fallback_compose_load(text)


def flatten_healthcheck_test(test: Any) -> str:
    if isinstance(test, str):
        return test.strip()
    if isinstance(test, list):
        parts: list[str] = []
        for item in test:
            text = str(item).strip()
            if text in {"CMD", "CMD-SHELL", "NONE"}:
                continue
            if text:
                parts.append(text)
        return " ".join(parts)
    return ""


def extract_healthcheck_target(healthcheck: Any) -> tuple[str, str]:
    if not isinstance(healthcheck, dict):
        return "", ""
    command = flatten_healthcheck_test(healthcheck.get("test"))
    if not command:
        return "", ""
    match = re.search(r"https?://[^\"'\s)]+", command)
    if not match:
        return "", ""
    target = match.group(0).rstrip("'\"")
    parsed = urlparse(target)
    return target, parsed.path or "/"


def load_catalog(files: list[Path]) -> list[ServiceRecord]:
    records: list[ServiceRecord] = []
    seen: set[str] = set()
    allowlist = configured_service_allowlist()
    for path in files:
        data = load_compose_data(path)
        services = data.get("services") or {}
        if not isinstance(services, dict):
            continue
        for service_name, cfg in services.items():
            if service_name in seen:
                continue
            if allowlist and service_name not in allowlist:
                continue
            seen.add(service_name)
            cfg = cfg or {}
            healthcheck = cfg.get("healthcheck")
            healthcheck_target, healthcheck_target_path = extract_healthcheck_target(healthcheck)
            records.append(
                ServiceRecord(
                    service=service_name,
                    container_name=str(cfg.get("container_name") or ""),
                    compose_file=str(path),
                    has_healthcheck=bool(healthcheck),
                    healthcheck_target=healthcheck_target,
                    healthcheck_target_path=healthcheck_target_path,
                )
            )
    return records


def docker_available() -> bool:
    return shutil.which(DOCKER_BIN) is not None


def run_docker(*args: str) -> subprocess.CompletedProcess[str]:
    command = [DOCKER_BIN, *args]
    try:
        return subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=False,
            timeout=DOCKER_TIMEOUT_SECS,
        )
    except subprocess.TimeoutExpired as exc:
        stderr = (exc.stderr or "").strip()
        timeout_message = f"command timed out after {DOCKER_TIMEOUT_SECS}s"
        stderr = f"{stderr}\n{timeout_message}".strip()
        return subprocess.CompletedProcess(
            command,
            124,
            (exc.stdout or "").strip(),
            stderr,
        )


def unique_values(values: list[str]) -> list[str]:
    items: list[str] = []
    seen: set[str] = set()
    for value in values:
        normalized = value.strip()
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        items.append(normalized)
    return items


def resolve_container_name(ref: str) -> str:
    result = run_docker("inspect", "--format", "{{.Name}}", ref)
    if result.returncode == 0 and result.stdout.strip():
        return result.stdout.strip().lstrip("/")
    return ref


def resolve_service(catalog: list[ServiceRecord], service_name: str) -> ServiceRecord:
    for record in catalog:
        if record.service == service_name:
            return record
    raise SystemExit(f"unknown service: {service_name}")


def discover_containers(record: ServiceRecord) -> list[str]:
    if record.container_name:
        return [record.container_name]
    if docker_available():
        compose_result = run_docker("compose", "-f", record.compose_file, "ps", "-q", record.service)
        if compose_result.returncode == 0:
            refs = unique_values(compose_result.stdout.splitlines())
            if refs:
                return unique_values([resolve_container_name(ref) for ref in refs])
    if docker_available():
        result = run_docker(
            "ps",
            "-a",
            "--filter",
            f"label=com.docker.compose.service={record.service}",
            "--format",
            "{{.Names}}",
        )
        if result.returncode == 0:
            names = unique_values(result.stdout.splitlines())
            if names:
                return names
    return [record.service]


def inspect_container(container_name: str) -> dict[str, Any]:
    if not docker_available():
        return {
            "container": container_name,
            "status": "docker-unavailable",
            "running": False,
            "health": "",
            "restart_count": 0,
            "exit_code": None,
            "error": "",
        }
    result = run_docker("inspect", container_name)
    if result.returncode != 0 or not result.stdout.strip():
        return {
            "container": container_name,
            "status": "missing",
            "running": False,
            "health": "",
            "restart_count": 0,
            "exit_code": None,
            "error": "",
        }
    data = json.loads(result.stdout)[0]
    state = data.get("State") or {}
    health = ((state.get("Health") or {}).get("Status")) or ""
    status = health or state.get("Status") or ("running" if state.get("Running") else "unknown")
    return {
        "container": container_name,
        "status": status,
        "running": bool(state.get("Running")),
        "health": health,
        "restart_count": int(state.get("RestartCount") or 0),
        "exit_code": state.get("ExitCode"),
        "started_at": state.get("StartedAt") or "",
        "finished_at": state.get("FinishedAt") or "",
        "error": str(state.get("Error") or ""),
    }


def service_health(record: ServiceRecord) -> dict[str, Any]:
    containers = discover_containers(record)
    container_states = [inspect_container(name) for name in containers]
    statuses = [item["status"] for item in container_states]
    ok_statuses = {"healthy", "running"}
    if statuses and all(status in ok_statuses for status in statuses):
        service_status = "ok"
    elif statuses and all(status == "missing" for status in statuses):
        service_status = "missing"
    elif statuses and all(status == "docker-unavailable" for status in statuses):
        service_status = "unknown"
    else:
        service_status = "degraded"
    return {
        "service": record.service,
        "status": service_status,
        "compose_file": record.compose_file,
        "containers": container_states,
        "container_count": len(container_states),
        "has_healthcheck": record.has_healthcheck,
    }


def overall_health_status(services: list[dict[str, Any]]) -> str:
    if not services:
        return "missing"
    statuses = {service["status"] for service in services}
    if statuses == {"ok"}:
        return "ok"
    if "degraded" in statuses or "ok" in statuses:
        return "degraded"
    if statuses == {"unknown"}:
        return "unknown"
    return "missing"


def history_path() -> Path:
    return HISTORY_FILE


def load_history_events(limit: int | None = None) -> list[dict[str, Any]]:
    path = history_path()
    if not path.exists():
        return []
    events: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    if limit is None or limit <= 0:
        return events
    return events[-limit:]


def append_history(event: dict[str, Any]) -> None:
    path = history_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(event, ensure_ascii=False) + "\n")


def latest_applied_action(service_name: str) -> dict[str, Any] | None:
    for event in reversed(load_history_events()):
        if event.get("kind") != "autopilot":
            continue
        for item in reversed(event.get("actions", [])):
            if item.get("service") == service_name and item.get("applied"):
                return item
    return None


def parse_iso8601(value: str) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def cooldown_remaining(last_action: dict[str, Any] | None, cooldown_secs: int) -> int:
    if not last_action or cooldown_secs <= 0:
        return 0
    timestamp = parse_iso8601(str(last_action.get("timestamp") or ""))
    if timestamp is None:
        return 0
    elapsed = (datetime.now(timezone.utc) - timestamp).total_seconds()
    return max(0, int(cooldown_secs - elapsed))


def parse_percent(value: str) -> float | None:
    raw = value.strip()
    if not raw:
        return None
    raw = raw.replace("%", "").strip()
    try:
        return float(raw)
    except ValueError:
        return None


def parse_memory_ratio(value: str) -> float | None:
    if "/" not in value:
        return None
    used, total = [part.strip() for part in value.split("/", 1)]
    used_bytes = parse_byte_size(used)
    total_bytes = parse_byte_size(total)
    if not used_bytes or not total_bytes:
        return None
    return round((used_bytes / total_bytes) * 100, 2)


def parse_byte_size(value: str) -> float | None:
    match = re.match(r"^\s*([0-9]*\.?[0-9]+)\s*([A-Za-z]+)\s*$", value)
    if not match:
        return None
    amount = float(match.group(1))
    unit = match.group(2).lower()
    factors = {
        "b": 1,
        "kb": 1000,
        "kib": 1024,
        "mb": 1000**2,
        "mib": 1024**2,
        "gb": 1000**3,
        "gib": 1024**3,
        "tb": 1000**4,
        "tib": 1024**4,
    }
    factor = factors.get(unit)
    if factor is None:
        return None
    return amount * factor


def fetch_container_stats(container_name: str) -> dict[str, Any]:
    if not docker_available():
        return {
            "container": container_name,
            "available": False,
            "cpu_percent": None,
            "mem_percent": None,
            "raw": {},
        }
    result = run_docker("stats", "--no-stream", "--format", "{{ json . }}", container_name)
    if result.returncode != 0:
        return {
            "container": container_name,
            "available": False,
            "cpu_percent": None,
            "mem_percent": None,
            "raw": {},
        }
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if not lines:
        return {
            "container": container_name,
            "available": False,
            "cpu_percent": None,
            "mem_percent": None,
            "raw": {},
        }
    try:
        payload = json.loads(lines[-1])
    except json.JSONDecodeError:
        payload = {}
    mem_percent = parse_percent(str(payload.get("MemPerc") or "")) or parse_memory_ratio(
        str(payload.get("MemUsage") or "")
    )
    return {
        "container": container_name,
        "available": True,
        "cpu_percent": parse_percent(str(payload.get("CPUPerc") or "")),
        "mem_percent": mem_percent,
        "raw": payload,
    }


def fetch_container_logs(container_name: str, tail_lines: int) -> dict[str, Any]:
    if not docker_available():
        return {
            "container": container_name,
            "available": False,
            "signals": {name: 0 for name in LOG_PATTERNS},
            "matches": [],
            "tail_preview": [],
            "line_count": 0,
        }
    result = run_docker("logs", "--tail", str(tail_lines), container_name)
    combined = "\n".join(
        part.strip()
        for part in (result.stdout, result.stderr)
        if part and part.strip()
    )
    lines = [line.rstrip() for line in combined.splitlines() if line.strip()]
    signals = {name: 0 for name in LOG_PATTERNS}
    matches: list[str] = []
    for line in lines:
        for name, pattern in LOG_PATTERNS.items():
            if pattern.search(line):
                signals[name] += 1
                if len(matches) < 5:
                    matches.append(line[-300:])
    return {
        "container": container_name,
        "available": result.returncode == 0,
        "signals": signals,
        "matches": matches,
        "tail_preview": lines[-5:],
        "line_count": len(lines),
    }


def add_reason(reasons: list[str], message: str) -> None:
    if message not in reasons:
        reasons.append(message)


def aggregate_signal_totals(logs: list[dict[str, Any]]) -> dict[str, int]:
    totals = {name: 0 for name in LOG_PATTERNS}
    for item in logs:
        for name, count in item.get("signals", {}).items():
            totals[name] = totals.get(name, 0) + int(count or 0)
    return totals


def signal_penalty(name: str, count: int) -> int:
    weight = SIGNAL_SCORE_WEIGHTS.get(name, 5)
    cap = SIGNAL_SCORE_CAPS.get(name, 20)
    return min(cap, count * weight)


def infer_risk_level(score: int) -> str:
    if score >= 85:
        return "low"
    if score >= 65:
        return "medium"
    if score >= 40:
        return "high"
    return "critical"


def infer_recommendation(
    health_payload: dict[str, Any],
    signal_totals: dict[str, int],
    max_restart_count: int,
    max_cpu: float | None,
    max_mem: float | None,
    healthcheck_target_path: str,
) -> tuple[str, float, str]:
    containers = health_payload["containers"]
    container_count = max(health_payload["container_count"], 1)
    restart_action = "rolling-restart" if container_count > 1 else "restart"
    statuses = {container["status"] for container in containers}

    if health_payload["status"] == "missing":
        return "manual-compose-up", 0.98, "service containers are missing"
    if "docker-unavailable" in statuses:
        return "inspect-manual", 0.99, "docker is unavailable from the supervisor runtime"
    if signal_totals.get("oom", 0) > 0:
        return "inspect-manual", 0.93, "OOM signal detected in recent logs"
    if signal_totals.get("insecure_admin_api", 0) > 0:
        return "harden-config", 0.86, "admin API is exposed without authentication"
    if max_restart_count > DEFAULT_MAX_RESTART_COUNT:
        return "inspect-manual", 0.91, "restart count exceeded the safe automation budget"
    if statuses & {"exited", "dead"}:
        return restart_action, 0.88, "container is down and restart budget is still available"
    if statuses & {"unhealthy", "restarting", "created"}:
        return restart_action, 0.81, "healthcheck or runtime state is degraded"
    if signal_totals.get("reactor_stall", 0) > 0 and (
        (max_cpu is not None and max_cpu >= 70) or (max_mem is not None and max_mem >= 70)
    ):
        return "investigate-capacity", 0.74, "reactor stalls detected under load"
    if healthcheck_target_path == "/docs" and signal_totals.get("docs_probe", 0) > 0:
        return "tune-healthcheck", 0.79, "healthcheck is probing /docs and generating log noise"
    if healthcheck_target_path == "/openapi.json" and signal_totals.get("openapi_probe", 0) > 0:
        return "tune-healthcheck", 0.71, "healthcheck is probing /openapi.json and generating log noise"
    if (max_cpu is not None and max_cpu >= 90) or (max_mem is not None and max_mem >= 90):
        return "investigate-capacity", 0.72, "resource usage is near saturation"
    if signal_totals.get("traceback", 0) > 0 or signal_totals.get("exception", 0) > 0:
        return restart_action, 0.69, "runtime errors are visible in recent logs"
    if signal_totals.get("gateway", 0) > 0:
        return "watch", 0.58, "gateway-level warnings detected but service is still running"
    if health_payload["status"] == "ok":
        return "observe", 0.96, "all tracked containers are healthy"
    return "watch", 0.51, "service is running but signals are mixed"


def diagnose_service(record: ServiceRecord, *, log_lines: int, cooldown_secs: int) -> dict[str, Any]:
    health_payload = service_health(record)
    stats = [fetch_container_stats(item["container"]) for item in health_payload["containers"]]
    logs = [fetch_container_logs(item["container"], log_lines) for item in health_payload["containers"]]
    signal_totals = aggregate_signal_totals(logs)
    reasons: list[str] = []
    score = 100

    if health_payload["status"] == "missing":
        score -= 70
        add_reason(reasons, "service has no live containers")
    elif health_payload["status"] == "degraded":
        score -= 45
        add_reason(reasons, "service health is degraded")
    elif health_payload["status"] == "unknown":
        score -= 35
        add_reason(reasons, "docker is unavailable to inspect the service")

    if not record.has_healthcheck:
        score -= 5
        add_reason(reasons, "compose service has no healthcheck")
    elif record.healthcheck_target_path in {"/docs", "/openapi.json"}:
        score -= 6 if record.healthcheck_target_path == "/docs" else 3
        add_reason(reasons, f"compose healthcheck probes {record.healthcheck_target_path}")

    max_restart_count = 0
    for container in health_payload["containers"]:
        status = container["status"]
        restart_count = int(container.get("restart_count") or 0)
        max_restart_count = max(max_restart_count, restart_count)
        if status in {"exited", "dead"}:
            score -= 25
            add_reason(reasons, f"{container['container']} is {status}")
        elif status in {"unhealthy", "restarting", "created"}:
            score -= 18
            add_reason(reasons, f"{container['container']} is {status}")
        elif status == "missing":
            score -= 30
            add_reason(reasons, f"{container['container']} is missing")
        if restart_count > 0:
            score -= min(20, restart_count * 4)
            add_reason(reasons, f"{container['container']} restart_count={restart_count}")
        exit_code = container.get("exit_code")
        if exit_code not in (None, 0) and not container.get("running"):
            add_reason(reasons, f"{container['container']} exit_code={exit_code}")
        error = str(container.get("error") or "").strip()
        if error:
            add_reason(reasons, f"{container['container']} docker_error={error}")

    for name, count in signal_totals.items():
        if count <= 0:
            continue
        score -= signal_penalty(name, count)
        add_reason(reasons, f"log signal {name} x{count}")

    cpu_values = [item["cpu_percent"] for item in stats if item["cpu_percent"] is not None]
    mem_values = [item["mem_percent"] for item in stats if item["mem_percent"] is not None]
    max_cpu = max(cpu_values) if cpu_values else None
    max_mem = max(mem_values) if mem_values else None

    if max_cpu is not None and max_cpu >= 85:
        score -= 10
        add_reason(reasons, f"cpu pressure maxed at {max_cpu:.2f}%")
    if max_mem is not None and max_mem >= 85:
        score -= 10
        add_reason(reasons, f"memory pressure maxed at {max_mem:.2f}%")

    score = max(0, min(100, score))
    recommended_action, confidence, recommendation_reason = infer_recommendation(
        health_payload,
        signal_totals,
        max_restart_count,
        max_cpu,
        max_mem,
        record.healthcheck_target_path,
    )
    add_reason(reasons, recommendation_reason)

    last_action = latest_applied_action(record.service)
    cooldown_remaining_secs = cooldown_remaining(last_action, cooldown_secs)

    return {
        "service": record.service,
        "status": health_payload["status"],
        "compose_file": record.compose_file,
        "compose_healthcheck": record.has_healthcheck,
        "healthcheck_target": record.healthcheck_target,
        "healthcheck_target_path": record.healthcheck_target_path,
        "container_count": health_payload["container_count"],
        "containers": health_payload["containers"],
        "stats": stats,
        "logs": logs,
        "signal_totals": signal_totals,
        "quantum_score": score,
        "risk_level": infer_risk_level(score),
        "recommended_action": recommended_action,
        "recommendation_confidence": round(confidence, 2),
        "reasons": reasons,
        "last_action": last_action,
        "cooldown_remaining_secs": cooldown_remaining_secs,
    }


def select_catalog(catalog: list[ServiceRecord], service_name: str | None) -> list[ServiceRecord]:
    if service_name is None:
        return catalog
    return [resolve_service(catalog, service_name)]


def emit_services(catalog: list[ServiceRecord], as_json: bool) -> int:
    payload = {
        "status": "ok",
        "service_count": len(catalog),
        "compose_files": sorted({record.compose_file for record in catalog}),
        "services": [asdict(record) for record in catalog],
    }
    if as_json:
        print(json.dumps(payload, indent=2))
    else:
        for record in catalog:
            print(f"{record.service}\t{record.container_name or '-'}\t{record.compose_file}")
    return 0


def emit_health(catalog: list[ServiceRecord], as_json: bool) -> int:
    services = [service_health(record) for record in catalog]
    payload = {
        "status": overall_health_status(services),
        "service_count": len(services),
        "healthy_services": sum(1 for item in services if item["status"] == "ok"),
        "services": services,
    }
    if as_json:
        print(json.dumps(payload, indent=2))
    else:
        for item in services:
            containers = ",".join(container["container"] for container in item["containers"])
            print(f"{item['service']}\t{item['status']}\t{containers}")
    return 0


def emit_diagnosis(
    diagnoses: list[dict[str, Any]],
    *,
    as_json: bool,
    log_lines: int,
    cooldown_secs: int,
) -> int:
    payload = {
        "status": overall_health_status(diagnoses),
        "service_count": len(diagnoses),
        "generated_at": utcnow_iso(),
        "log_lines": log_lines,
        "cooldown_secs": cooldown_secs,
        "history_file": str(history_path()),
        "services": diagnoses,
    }
    if as_json:
        print(json.dumps(payload, indent=2))
    else:
        for item in diagnoses:
            print(
                f"{item['service']}\t{item['status']}\t"
                f"score={item['quantum_score']}\taction={item['recommended_action']}"
            )
    return 0


def ensure_restart_prereqs() -> None:
    if not docker_available():
        raise SystemExit(f"docker binary not found: {DOCKER_BIN}")


def restart_containers(containers: list[str], dry_run: bool) -> list[str]:
    restarted = []
    for container in containers:
        if not dry_run:
            result = run_docker("restart", container)
            if result.returncode != 0:
                raise SystemExit(result.stderr.strip() or f"failed to restart {container}")
        restarted.append(container)
    return restarted


def restart_service(record: ServiceRecord, *, delay_secs: float, dry_run: bool) -> list[str]:
    containers = discover_containers(record)
    if len(containers) <= 1:
        return restart_containers(containers, dry_run=dry_run)
    restarted: list[str] = []
    for index, container in enumerate(containers):
        restarted.extend(restart_containers([container], dry_run=dry_run))
        if index < len(containers) - 1 and delay_secs > 0:
            time.sleep(delay_secs)
    return restarted


def emit_action(
    action: str,
    service: str,
    containers: list[str],
    restarted: list[str],
    as_json: bool,
    dry_run: bool,
    delay_secs: float | None = None,
) -> int:
    payload = {
        "status": "ok",
        "action": action,
        "service": service,
        "containers": containers,
        "restarted": restarted,
        "dry_run": dry_run,
    }
    if delay_secs is not None:
        payload["delay_secs"] = delay_secs
    if as_json:
        print(json.dumps(payload, indent=2))
    else:
        print(f"{action} {service}: {','.join(restarted)}")
    return 0


def compose_specs_from_args(args: argparse.Namespace) -> list[str]:
    parts: list[str] = []
    for item in getattr(args, "compose_file", None) or []:
        parts.append(item)
    raw = getattr(args, "compose_files", None)
    if raw:
        parts.extend(split_compose_spec(raw))
    return parts


def cmd_services(args: argparse.Namespace, catalog: list[ServiceRecord]) -> int:
    return emit_services(catalog, args.json)


def cmd_health(args: argparse.Namespace, catalog: list[ServiceRecord]) -> int:
    return emit_health(catalog, args.json)


def cmd_restart(args: argparse.Namespace, catalog: list[ServiceRecord]) -> int:
    record = resolve_service(catalog, args.service)
    containers = discover_containers(record)
    dry_run = args.dry_run or DEFAULT_DRY_RUN
    if not dry_run:
        ensure_restart_prereqs()
    restarted = restart_containers(containers, dry_run=dry_run)
    return emit_action("restart", record.service, containers, restarted, args.json, dry_run)


def cmd_rolling_restart(args: argparse.Namespace, catalog: list[ServiceRecord]) -> int:
    record = resolve_service(catalog, args.service)
    containers = discover_containers(record)
    dry_run = args.dry_run or DEFAULT_DRY_RUN
    delay_secs = args.delay_secs
    if not dry_run:
        ensure_restart_prereqs()
    restarted = []
    for index, container in enumerate(containers):
        restarted.extend(restart_containers([container], dry_run=dry_run))
        if index < len(containers) - 1 and delay_secs > 0:
            time.sleep(delay_secs)
    return emit_action(
        "rolling-restart",
        record.service,
        containers,
        restarted,
        args.json,
        dry_run,
        delay_secs=delay_secs,
    )


def cmd_diagnose(args: argparse.Namespace, catalog: list[ServiceRecord]) -> int:
    selected = select_catalog(catalog, getattr(args, "service", None))
    diagnoses = [
        diagnose_service(record, log_lines=args.log_lines, cooldown_secs=args.cooldown_secs)
        for record in selected
    ]
    append_history(
        {
            "kind": "diagnose",
            "timestamp": utcnow_iso(),
            "service": getattr(args, "service", None),
            "status": overall_health_status(diagnoses),
            "log_lines": args.log_lines,
            "services": [
                {
                    "service": item["service"],
                    "status": item["status"],
                    "quantum_score": item["quantum_score"],
                    "recommended_action": item["recommended_action"],
                }
                for item in diagnoses
            ],
        }
    )
    return emit_diagnosis(
        diagnoses,
        as_json=args.json,
        log_lines=args.log_lines,
        cooldown_secs=args.cooldown_secs,
    )


def cmd_autopilot(args: argparse.Namespace, catalog: list[ServiceRecord]) -> int:
    selected = select_catalog(catalog, getattr(args, "service", None))
    apply_changes = bool(args.apply)
    delay_secs = args.delay_secs
    actions: list[dict[str, Any]] = []

    if apply_changes:
        ensure_restart_prereqs()

    for record in selected:
        diagnosis = diagnose_service(record, log_lines=args.log_lines, cooldown_secs=args.cooldown_secs)
        decision = diagnosis["recommended_action"]
        blocked_by: list[str] = []
        restarted: list[str] = []
        applied = False

        if decision not in ACTIONABLE_DECISIONS:
            blocked_by.append("non-actionable-decision")
        if diagnosis["cooldown_remaining_secs"] > 0:
            blocked_by.append("cooldown-active")
        max_seen_restart = max(
            (int(container.get("restart_count") or 0) for container in diagnosis["containers"]),
            default=0,
        )
        if max_seen_restart > args.max_restart_count:
            blocked_by.append("restart-budget-exceeded")

        if apply_changes and not blocked_by:
            restarted = restart_service(record, delay_secs=delay_secs, dry_run=False)
            applied = True
        elif not apply_changes and decision in ACTIONABLE_DECISIONS and "cooldown-active" not in blocked_by:
            restarted = [container["container"] for container in diagnosis["containers"]]

        actions.append(
            {
                "timestamp": utcnow_iso(),
                "service": record.service,
                "decision": decision,
                "recommended_action": decision,
                "status": diagnosis["status"],
                "quantum_score": diagnosis["quantum_score"],
                "risk_level": diagnosis["risk_level"],
                "reasons": diagnosis["reasons"],
                "containers": [container["container"] for container in diagnosis["containers"]],
                "restarted": restarted,
                "applied": applied,
                "apply_requested": apply_changes,
                "blocked_by": blocked_by,
                "cooldown_remaining_secs": diagnosis["cooldown_remaining_secs"],
                "recommendation_confidence": diagnosis["recommendation_confidence"],
            }
        )

    payload = {
        "status": "ok",
        "mode": "apply" if apply_changes else "dry-run",
        "generated_at": utcnow_iso(),
        "history_file": str(history_path()),
        "actions": actions,
    }
    append_history(
        {
            "kind": "autopilot",
            "timestamp": payload["generated_at"],
            "mode": payload["mode"],
            "actions": actions,
        }
    )

    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        for item in actions:
            suffix = "applied" if item["applied"] else "planned"
            print(f"{item['service']}\t{item['decision']}\t{suffix}")
    return 0


def cmd_history(args: argparse.Namespace, catalog: list[ServiceRecord]) -> int:
    del catalog
    events = load_history_events(limit=args.limit)
    payload = {
        "status": "ok",
        "history_file": str(history_path()),
        "event_count": len(events),
        "events": events,
    }
    if args.json:
        print(json.dumps(payload, indent=2))
    else:
        for event in events:
            print(f"{event.get('timestamp','')}\t{event.get('kind','')}")
    return 0


def add_compose_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--compose-file",
        action="append",
        default=None,
        help="Compose file to inspect; can be repeated",
    )
    parser.add_argument(
        "--compose-files",
        default=None,
        help="Comma/colon-separated compose file list",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="SupervizorAI",
        description="Lightweight supervisor for compose-backed QuantumAI services.",
    )
    subparsers = parser.add_subparsers(dest="command")

    services = subparsers.add_parser("services", help="List tracked services")
    add_compose_args(services)
    services.add_argument("--json", action="store_true", help="Emit JSON")
    services.set_defaults(func=cmd_services)

    health = subparsers.add_parser("health", help="Aggregate service health")
    add_compose_args(health)
    health.add_argument("--json", action="store_true", help="Emit JSON")
    health.set_defaults(func=cmd_health)

    restart = subparsers.add_parser("restart", help="Restart all containers for a service")
    add_compose_args(restart)
    restart.add_argument("service", help="Service name")
    restart.add_argument("--dry-run", action="store_true", help="Do not call docker restart")
    restart.add_argument("--json", action="store_true", help="Emit JSON")
    restart.set_defaults(func=cmd_restart)

    rolling = subparsers.add_parser(
        "rolling-restart",
        help="Restart service containers one at a time",
    )
    add_compose_args(rolling)
    rolling.add_argument("service", help="Service name")
    rolling.add_argument(
        "--delay-secs",
        type=float,
        default=DEFAULT_DELAY,
        help="Delay between container restarts",
    )
    rolling.add_argument("--dry-run", action="store_true", help="Do not call docker restart")
    rolling.add_argument("--json", action="store_true", help="Emit JSON")
    rolling.set_defaults(func=cmd_rolling_restart)

    diagnose = subparsers.add_parser(
        "diagnose",
        help="QuantumAI diagnosis for one service or the whole stack",
    )
    add_compose_args(diagnose)
    diagnose.add_argument("service", nargs="?", help="Optional service name")
    diagnose.add_argument("--log-lines", type=int, default=DEFAULT_LOG_LINES, help="Recent log lines to inspect")
    diagnose.add_argument(
        "--cooldown-secs",
        type=int,
        default=DEFAULT_COOLDOWN_SECS,
        help="Automation cooldown window used in the diagnosis",
    )
    diagnose.add_argument("--json", action="store_true", help="Emit JSON")
    diagnose.set_defaults(func=cmd_diagnose)

    autopilot = subparsers.add_parser(
        "autopilot",
        help="Plan or apply safe remediation actions for degraded services",
    )
    add_compose_args(autopilot)
    autopilot.add_argument("service", nargs="?", help="Optional service name")
    autopilot.add_argument("--log-lines", type=int, default=DEFAULT_LOG_LINES, help="Recent log lines to inspect")
    autopilot.add_argument(
        "--cooldown-secs",
        type=int,
        default=DEFAULT_COOLDOWN_SECS,
        help="Do not repeat an applied action within this window",
    )
    autopilot.add_argument(
        "--max-restart-count",
        type=int,
        default=DEFAULT_MAX_RESTART_COUNT,
        help="Block automation when a container already restarted more than this count",
    )
    autopilot.add_argument(
        "--delay-secs",
        type=float,
        default=DEFAULT_DELAY,
        help="Delay between rolling restarts when apply mode is active",
    )
    autopilot.add_argument("--apply", action="store_true", help="Execute restart actions")
    autopilot.add_argument("--json", action="store_true", help="Emit JSON")
    autopilot.set_defaults(func=cmd_autopilot)

    history = subparsers.add_parser("history", help="Show ManagerAI diagnosis/action history")
    add_compose_args(history)
    history.add_argument("--limit", type=int, default=DEFAULT_HISTORY_LIMIT, help="How many events to return")
    history.add_argument("--json", action="store_true", help="Emit JSON")
    history.set_defaults(func=cmd_history)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if args.command is None:
        parser.print_help()
        return 0
    files = configured_compose_files(compose_specs_from_args(args))
    catalog = load_catalog(files)
    return int(args.func(args, catalog))


if __name__ == "__main__":
    raise SystemExit(main())
