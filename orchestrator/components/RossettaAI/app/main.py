#!/usr/bin/env python3
import hashlib
import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

SERVICE = os.environ.get("SERVICE_NAME", "RossettaAI")
START = time.time()
MODEL_PATH = os.environ.get("MODEL_PATH", "/modeldata/trainedmodel.json")
_model_lock = threading.Lock()


class ModelStore:

    def __init__(self, path: str | os.PathLike[str] | None=None) -> None:
        self.path = Path(path or MODEL_PATH)
        self._model: dict[str, object] | None = None
        self.load()

    def load(self) -> None:
        try:
            with self.path.open("r", encoding="utf-8") as handle:
                payload = json.load(handle)
        except Exception as exc:  # pragma: no cover - exercised by tests via missing file path
            payload = {"error": str(exc), "loaded": False}
        if isinstance(payload, dict):
            payload = dict(payload)
            payload.setdefault("loaded", True)
            self._model = payload
        else:
            self._model = {"loaded": False}

    def snapshot(self) -> dict[str, object]:
        model = self._model or {}
        raw = json.dumps(model, sort_keys=True, ensure_ascii=False).encode("utf-8")
        return {
            "loaded": bool(model.get("loaded", False)) if isinstance(model, dict) else False,
            "model_id": model.get("id") if isinstance(model, dict) else None,
            "sha256": hashlib.sha256(raw).hexdigest(),
            "path": str(self.path),
        }

    def predict(self, text: str) -> dict[str, object]:
        normalized = str(text or "")
        length = len(normalized)
        if length > 10:
            label = "bullish"
        elif length > 5:
            label = "neutral"
        else:
            label = "bearish"
        return {
            "model": self.snapshot(),
            "prediction": {
                "label": label,
                "character_count": length,
                "input": normalized,
            },
        }


MODEL_STORE = ModelStore(MODEL_PATH)


class H(BaseHTTPRequestHandler):

    def do_GET(self):
        if self.path.startswith("/health"):
            body = json.dumps({"service": SERVICE, "uptime_s": round(time.time() - START, 2), "status": "ok"})
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body.encode())
        elif self.path.startswith("/model"):
            with _model_lock:
                body = json.dumps({"service": SERVICE, "model": MODEL_STORE._model})
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body.encode())
        elif self.path.startswith("/predict"):
            from urllib.parse import parse_qs, urlparse

            qs = parse_qs(urlparse(self.path).query)
            inp = qs.get("q", [""])[0]
            with _model_lock:
                response = {
                    "service": SERVICE,
                    "input": inp,
                    "model_id": MODEL_STORE._model.get("id") if isinstance(MODEL_STORE._model, dict) else None,
                    "prediction": inp[::-1],
                }
            body = json.dumps(response)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(body.encode())
        else:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"RossettaAI service placeholder")


if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8080"))
    HTTPServer(("0.0.0.0", port), H).serve_forever()
