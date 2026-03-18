#!/usr/bin/env bash
set -euo pipefail

exec python3 - "$0" "$@" <<'PY'
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
from pathlib import Path
from typing import Any

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


SCRIPT_PATH = Path(sys.argv[1]).resolve()
ARGV = sys.argv[2:]
REPO_ROOT = SCRIPT_PATH.parent.parent
DOCKER_BIN = os.environ.get("SUPERVIZOR_DOCKER_BIN", "docker")
DEFAULT_DELAY = float(os.environ.get("SUPERVIZOR_ROLLING_DELAY_SECS", "2"))
DEFAULT_DRY_RUN = os.environ.get("SUPERVIZOR_DRY_RUN", "0") == "1"


def split_compose_spec(raw: str) -> list[str]:
    return [part.strip() for part in re.split(r"[:,]", raw) if part.strip()]


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
    candidates = [
        REPO_ROOT / "compose.yml",
        REPO_ROOT / "compose.master.yml",
        REPO_ROOT / "stack" / "docker-compose.yml",
        REPO_ROOT / "docker-compose.yml",
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


def load_catalog(files: list[Path]) -> list[ServiceRecord]:
    records: list[ServiceRecord] = []
    seen: set[str] = set()
    for path in files:
        data = load_compose_data(path)
        services = data.get("services") or {}
        if not isinstance(services, dict):
            continue
        for service_name, cfg in services.items():
            if service_name in seen:
                continue
            seen.add(service_name)
            cfg = cfg or {}
            records.append(
                ServiceRecord(
                    service=service_name,
                    container_name=str(cfg.get("container_name") or ""),
                    compose_file=str(path),
                    has_healthcheck=bool(cfg.get("healthcheck")),
                )
            )
    return records


def docker_available() -> bool:
    return shutil.which(DOCKER_BIN) is not None


def run_docker(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [DOCKER_BIN, *args],
        capture_output=True,
        text=True,
        check=False,
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
    if docker_available():
        compose_result = run_docker("compose", "-f", record.compose_file, "ps", "-q", record.service)
        if compose_result.returncode == 0:
            refs = unique_values(compose_result.stdout.splitlines())
            if refs:
                return unique_values([resolve_container_name(ref) for ref in refs])
    if record.container_name:
        return [record.container_name]
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
        }
    result = run_docker("inspect", container_name)
    if result.returncode != 0 or not result.stdout.strip():
        return {
            "container": container_name,
            "status": "missing",
            "running": False,
            "health": "",
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

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args(ARGV)
    if args.command is None:
        parser.print_help()
        return 0
    files = configured_compose_files(compose_specs_from_args(args))
    catalog = load_catalog(files)
    return int(args.func(args, catalog))


if __name__ == "__main__":
    raise SystemExit(main())
PY
