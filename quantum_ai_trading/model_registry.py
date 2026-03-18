from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import joblib

from .config import QuantumAITradingConfig
from .schemas import TrainingArtifact


class ModelRegistry:
    def __init__(self, config: QuantumAITradingConfig):
        self.config = config

    def version_dir(self, model_name: str) -> Path:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        path = self.config.model_dir / model_name / stamp
        path.mkdir(parents=True, exist_ok=True)
        return path

    def save_bundle(
        self,
        model_name: str,
        model: Any,
        scaler: Any,
        payload: dict[str, Any],
    ) -> TrainingArtifact:
        vdir = self.version_dir(model_name)
        model_path = vdir / "model.joblib"
        scaler_path = vdir / "scaler.joblib"
        meta_path = vdir / "meta.json"

        joblib.dump(model, model_path)
        joblib.dump(scaler, scaler_path)
        meta_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")

        return TrainingArtifact(
            model_name=model_name,
            symbol=payload["symbol"],
            interval=payload["interval"],
            trained_at=payload["trained_at"],
            features=payload["features"],
            metrics=payload["metrics"],
            model_path=str(model_path),
            scaler_path=str(scaler_path),
            notes=payload.get("notes", {}),
        )

    def load_latest(self, model_name: str) -> tuple[Any, Any, dict[str, Any]]:
        base = self.config.model_dir / model_name
        versions = sorted([path for path in base.glob("*") if path.is_dir()])
        if not versions:
            raise FileNotFoundError(f"MODEL_NOT_FOUND:{model_name}")
        latest = versions[-1]
        model = joblib.load(latest / "model.joblib")
        scaler = joblib.load(latest / "scaler.joblib")
        meta = json.loads((latest / "meta.json").read_text(encoding="utf-8"))
        return model, scaler, meta
