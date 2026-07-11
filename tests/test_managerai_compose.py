from __future__ import annotations

import json
from pathlib import Path
import subprocess


ROOT = Path(__file__).resolve().parents[1]


def test_managerai_compose_is_self_contained_and_local_only():
    proc = subprocess.run(
        [
            "docker",
            "compose",
            "-f",
            str(ROOT / "compose.managerai.yml"),
            "config",
            "--format",
            "json",
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert proc.returncode == 0, proc.stderr
    payload = json.loads(proc.stdout)
    assert set(payload["services"]) == {"managerai", "managerai-broker", "managerai-guard"}
    assert payload["services"]["managerai"]["ports"][0]["host_ip"] == "127.0.0.1"
    assert payload["services"]["managerai-broker"]["ports"][0]["host_ip"] == "127.0.0.1"
    assert payload["services"]["managerai-guard"]["depends_on"]["managerai"]["condition"] == "service_healthy"


def test_managerai_stack_helper_deploys_only_dedicated_compose_file():
    script = (ROOT / "ops" / "qai_managerai_stack.sh").read_text(encoding="utf-8")

    assert 'COMPOSE_FILE="$ROOT/compose.managerai.yml"' in script
    assert 'ARGS=(-f "$COMPOSE_FILE")' in script
    assert "for file in compose.master.yml" not in script


def test_managerai_image_compose_inputs_are_not_dockerignored():
    dockerignore = (ROOT / ".dockerignore").read_text(encoding="utf-8").splitlines()
    required_inputs = {
        "compose.master.yml",
        "compose.yml",
        "compose.override.yml",
        "docker-compose.base.yml",
        "docker-compose.override.yml",
        "compose.managerai.yml",
    }

    for path in required_inputs:
        assert f"!{path}" in dockerignore
