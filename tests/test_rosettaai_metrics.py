from __future__ import annotations

import importlib.util
import json
import sys
from pathlib import Path
from uuid import uuid4


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:  # pragma: no cover
    sys.path.insert(0, str(ROOT))


def load_module(path: Path, name_prefix: str):
    module_name = f"{name_prefix}_{uuid4().hex}"
    spec = importlib.util.spec_from_file_location(module_name, path)
    if spec is None or spec.loader is None:  # pragma: no cover
        raise RuntimeError(f"unable to load {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_rosettaai_model_store_loads_and_predicts(tmp_path, monkeypatch):
    model_path = tmp_path / "trained_model.json"
    model_path.write_text(
        json.dumps(
            {
                "id": "test-model",
                "version": "1.2.3",
                "metadata": {"owner": "pytest"},
                "features": ["length"],
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setenv("MODEL_PATH", str(model_path))

    module = load_module(
        ROOT / "orchestrator" / "components" / "RossettaAI" / "app" / "main.py",
        "rosettaai_main",
    )

    snapshot = module.MODEL_STORE.snapshot()
    assert snapshot["loaded"] is True
    assert snapshot["model_id"] == "test-model"
    assert len(snapshot["sha256"]) == 64

    result = module.MODEL_STORE.predict("QuantumAI")
    assert result["model"]["loaded"] is True
    assert result["model"]["model_id"] == "test-model"
    assert result["prediction"]["label"] in {"bullish", "neutral", "bearish"}
    assert result["prediction"]["character_count"] == len("QuantumAI")


def test_metrics_exporter_parses_targets_and_renders_metrics():
    module = load_module(
        ROOT / "orchestrator" / "metrics" / "exporter.py",
        "metrics_exporter",
    )
    targets = module.parse_targets("gateway|gateway:8080/health,rosettaai|http://rosettaai:8080/health")
    assert targets == [
        {"service": "gateway", "target": "http://gateway:8080/health"},
        {"service": "rosettaai", "target": "http://rosettaai:8080/health"},
    ]

    text = module.render_metrics(
        [
            {
                "service": "gateway",
                "target": "http://gateway:8080/health",
                "ok": True,
                "status_code": 200,
                "duration_seconds": 0.1234,
                "timestamp": 1710000000,
            }
        ]
    )
    assert 'service_up{service="gateway",target="http://gateway:8080/health"} 1' in text
    assert 'service_http_status{service="gateway",target="http://gateway:8080/health"} 200' in text
