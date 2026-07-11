from pathlib import Path

import yaml


def test_root_dockerfile_runs_existing_python_entrypoint():
    dockerfile = Path("Dockerfile").read_text(encoding="utf-8")
    runtime_stage = dockerfile.split("FROM python:3.12-slim\n", maxsplit=1)[1]

    assert Path("app.py").is_file()
    assert "COPY requirements.txt" in dockerfile
    assert "HOST_PORT=5002" in runtime_stage
    assert 'CMD ["python", "app.py"]' in dockerfile
    assert "index.js" not in dockerfile


def test_root_compose_port_matches_application_port():
    compose = yaml.safe_load(Path("docker-compose.yml").read_text(encoding="utf-8"))
    service = compose["services"]["quantumai-usdt"]

    assert service["environment"]["HOST_PORT"] == "5002"
    assert service["ports"] == ["5003:5002"]
    assert "http://localhost:5002/health" in " ".join(service["healthcheck"]["test"])
