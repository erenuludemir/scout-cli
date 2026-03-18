from __future__ import annotations

import os
import time

from flask import Flask, jsonify

_started = time.time()


def create_app() -> Flask:
    app = Flask(__name__)

    @app.get("/")
    def root():
        return jsonify(
            ok=True,
            service="quantumai-usdt-v2",
            ready=(time.time() - _started) > 0.5,
            redis_url=os.getenv("REDIS_URL", ""),
        )

    @app.get("/health")
    def health():
        return jsonify(
            ok=True,
            service="quantumai-usdt-v2",
            ready=(time.time() - _started) > 0.5,
        )

    return app


app = create_app()
