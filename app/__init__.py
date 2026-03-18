from flask import Flask, jsonify

def create_app() -> Flask:
    app = Flask(__name__)

    @app.get("/")
    def root():
        return jsonify(ok=True), 200

    try:
        from integrations.etherscan.flask_ext import register_qai_etherscan
        register_qai_etherscan(app)
    except Exception:
        pass

    try:
        from integrations.linear.flask_ext import register_qai_linear
        register_qai_linear(app)
    except Exception:
        pass

    try:
        from health.blueprint import bp_health
        app.register_blueprint(bp_health)
    except Exception:
        @app.get("/health")
        def health():
            return jsonify(ok=True, status="ok"), 200

        @app.get("/healthz")
        def healthz():
            return jsonify(ok=True, status="ok"), 200

    return app

app = create_app()
application = app
