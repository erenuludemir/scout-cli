import json
import os
import stat
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "orchestrator" / "SupervizorAI.sh"


def write_fake_docker(tmp_path: Path) -> Path:
    fake = tmp_path / "docker"
    fake.write_text(
        """#!/usr/bin/env python3
import json
import os
import re
import sys


def sanitize(value):
    return re.sub(r"[^A-Za-z0-9]+", "_", value)


log_path = os.environ.get("FAKE_DOCKER_LOG")
if log_path:
    with open(log_path, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(sys.argv[1:]) + "\\n")

args = sys.argv[1:]
if not args:
    raise SystemExit(1)

command = args[0]
if command == "compose":
    service = args[-1] if args else ""
    if "ps" in args and "-q" in args:
        sys.stdout.write(
            os.environ.get(
                f"FAKE_DOCKER_COMPOSE_PS_{sanitize(service)}",
                os.environ.get(f"FAKE_DOCKER_PS_{sanitize(service)}", ""),
            )
        )
        raise SystemExit(0)
    raise SystemExit(1)

if command == "ps":
    service = ""
    for index, arg in enumerate(args):
        if arg == "--filter" and index + 1 < len(args):
            value = args[index + 1]
            if value.startswith("label=com.docker.compose.service="):
                service = value.split("=", 2)[-1]
                break
    sys.stdout.write(os.environ.get(f"FAKE_DOCKER_PS_{sanitize(service)}", ""))
    raise SystemExit(0)

if command == "inspect":
    if len(args) >= 4 and args[1] == "--format":
        container = args[3]
        name = os.environ.get(f"FAKE_DOCKER_NAME_{sanitize(container)}")
        if name is None:
            raise SystemExit(1)
        sys.stdout.write(name)
        raise SystemExit(0)
    container = args[1]
    payload = os.environ.get(f"FAKE_DOCKER_INSPECT_{sanitize(container)}")
    if payload is None:
        raise SystemExit(1)
    sys.stdout.write(payload)
    raise SystemExit(0)

if command == "restart":
    sys.stdout.write("\\n".join(args[1:]))
    raise SystemExit(0)

raise SystemExit(1)
""",
        encoding="utf-8",
    )
    fake.chmod(fake.stat().st_mode | stat.S_IEXEC)
    return fake


def run_supervizor(tmp_path: Path, args: list[str], extra_env: dict[str, str] | None = None):
    env = os.environ.copy()
    env["PATH"] = f"{tmp_path}:{env['PATH']}"
    env["SUPERVIZOR_DOCKER_BIN"] = "docker"
    if extra_env:
        env.update(extra_env)
    return subprocess.run(
        ["bash", str(SCRIPT), *args],
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
        check=False,
    )


def test_services_discovers_compose_services_as_json(tmp_path):
    compose_file = tmp_path / "compose.yml"
    compose_file.write_text(
        """
services:
  api:
    container_name: api-container
    healthcheck:
      test: ["CMD", "true"]
  worker:
    image: busybox
""".strip(),
        encoding="utf-8",
    )

    write_fake_docker(tmp_path)
    result = run_supervizor(
        tmp_path,
        ["services", "--json"],
        {"SUPERVIZOR_COMPOSE_FILES": str(compose_file)},
    )

    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["service_count"] == 2
    assert [item["service"] for item in payload["services"]] == ["api", "worker"]
    assert payload["services"][0]["container_name"] == "api-container"
    assert payload["services"][1]["container_name"] == ""


def test_invocation_without_command_prints_help(tmp_path):
    result = run_supervizor(tmp_path, [])

    assert result.returncode == 0
    assert "usage:" in result.stdout
    assert "services" in result.stdout


def test_services_accepts_compose_file_flag(tmp_path):
    compose_file = tmp_path / "compose.yml"
    compose_file.write_text(
        """
services:
  api:
    container_name: api-container
""".strip(),
        encoding="utf-8",
    )

    write_fake_docker(tmp_path)
    result = run_supervizor(
        tmp_path,
        ["services", "--compose-file", str(compose_file), "--json"],
    )

    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["service_count"] == 1
    assert payload["services"][0]["service"] == "api"


def test_health_aggregates_container_state_from_docker(tmp_path):
    compose_file = tmp_path / "compose.yml"
    compose_file.write_text(
        """
services:
  api:
    container_name: api-container
  worker:
    image: busybox
""".strip(),
        encoding="utf-8",
    )
    write_fake_docker(tmp_path)

    env = {
        "SUPERVIZOR_COMPOSE_FILES": str(compose_file),
        "FAKE_DOCKER_PS_worker": "worker-1\n",
        "FAKE_DOCKER_INSPECT_api_container": json.dumps(
            [{"State": {"Running": True, "Status": "running", "Health": {"Status": "healthy"}}}]
        ),
        "FAKE_DOCKER_INSPECT_worker_1": json.dumps(
            [{"State": {"Running": False, "Status": "exited"}}]
        ),
    }

    result = run_supervizor(tmp_path, ["health", "--json"], env)

    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["status"] == "degraded"
    services = {item["service"]: item for item in payload["services"]}
    assert services["api"]["status"] == "ok"
    assert services["api"]["containers"][0]["status"] == "healthy"
    assert services["worker"]["status"] == "degraded"
    assert services["worker"]["containers"][0]["status"] == "exited"


def test_health_prefers_current_compose_containers_over_stale_service_matches(tmp_path):
    compose_file = tmp_path / "compose.yml"
    compose_file.write_text(
        """
services:
  api:
    image: busybox
""".strip(),
        encoding="utf-8",
    )
    write_fake_docker(tmp_path)

    env = {
        "SUPERVIZOR_COMPOSE_FILES": str(compose_file),
        "FAKE_DOCKER_PS_api": "stale-api\nlive-api\n",
        "FAKE_DOCKER_COMPOSE_PS_api": "live-api\n",
        "FAKE_DOCKER_NAME_live_api": "/live-api",
        "FAKE_DOCKER_INSPECT_live_api": json.dumps(
            [{"State": {"Running": True, "Status": "running", "Health": {"Status": "healthy"}}}]
        ),
        "FAKE_DOCKER_INSPECT_stale_api": json.dumps(
            [{"State": {"Running": False, "Status": "created"}}]
        ),
    }

    result = run_supervizor(tmp_path, ["health", "--json"], env)

    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["status"] == "ok"
    service = payload["services"][0]
    assert service["status"] == "ok"
    assert service["container_count"] == 1
    assert service["containers"][0]["container"] == "live-api"
    assert service["containers"][0]["status"] == "healthy"


def test_rolling_restart_restarts_each_container_in_order(tmp_path):
    compose_file = tmp_path / "compose.yml"
    compose_file.write_text(
        """
services:
  worker:
    image: busybox
""".strip(),
        encoding="utf-8",
    )
    write_fake_docker(tmp_path)
    log_file = tmp_path / "docker.log"

    env = {
        "SUPERVIZOR_COMPOSE_FILES": str(compose_file),
        "FAKE_DOCKER_LOG": str(log_file),
        "FAKE_DOCKER_PS_worker": "worker-1\nworker-2\n",
    }

    result = run_supervizor(
        tmp_path,
        ["rolling-restart", "worker", "--delay-secs", "0", "--json"],
        env,
    )

    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["action"] == "rolling-restart"
    assert payload["restarted"] == ["worker-1", "worker-2"]

    calls = [json.loads(line) for line in log_file.read_text(encoding="utf-8").splitlines()]
    assert ["restart", "worker-1"] in calls
    assert ["restart", "worker-2"] in calls
