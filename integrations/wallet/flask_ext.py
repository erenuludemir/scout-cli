from __future__ import annotations

from flask import Blueprint, jsonify, request

from .multichain import MultiChainWalletService, WalletChainError

bp = Blueprint("qai_wallet", __name__)


def _service() -> MultiChainWalletService:
    return MultiChainWalletService()


def _json_error(message: str, status_code: int = 400):
    return jsonify(ok=False, error=message), status_code


@bp.errorhandler(ValueError)
def handle_value_error(exc: ValueError):
    return _json_error(str(exc), 400)


@bp.errorhandler(WalletChainError)
def handle_wallet_error(exc: WalletChainError):
    return _json_error(str(exc), 502)


@bp.get("/wallet/networks")
def wallet_networks():
    family = request.args.get("family")
    return jsonify(ok=True, result=_service().list_networks(family=family))


@bp.get("/wallet/balance")
def wallet_balance():
    network = request.args.get("network")
    address = request.args.get("address")
    if not network:
        raise ValueError("network required")
    if not address:
        raise ValueError("address required")
    return jsonify(ok=True, result=_service().get_balance(network=network, address=address))


@bp.get("/wallet/token-balance")
def wallet_token_balance():
    network = request.args.get("network")
    address = request.args.get("address")
    token_address = (
        request.args.get("token_address")
        or request.args.get("contractaddress")
        or request.args.get("mint")
    )
    if not network:
        raise ValueError("network required")
    if not address:
        raise ValueError("address required")
    if not token_address:
        raise ValueError("token_address required")
    return jsonify(
        ok=True,
        result=_service().get_token_balance(
            network=network,
            address=address,
            token_address=token_address,
        ),
    )


@bp.post("/wallet/broadcast")
def wallet_broadcast():
    payload = request.get_json(silent=True) or request.form.to_dict() or {}
    if not payload:
        raise ValueError("broadcast payload required")
    network = payload.get("network")
    if not network:
        raise ValueError("network required")
    return jsonify(
        ok=True,
        result=_service().broadcast(
            network=network,
            raw_transaction=payload.get("raw_transaction") or payload.get("signed_hex"),
            payload=payload.get("payload"),
            encoding=payload.get("encoding"),
        ),
    )


@bp.post("/wallet/portfolio")
def wallet_portfolio():
    payload = request.get_json(silent=True) or {}
    addresses = payload.get("addresses") or {}
    if not isinstance(addresses, dict) or not addresses:
        raise ValueError("addresses map required")
    networks = payload.get("networks")
    return jsonify(ok=True, result=_service().build_portfolio(addresses=addresses, networks=networks))


def register_qai_wallet(app):
    if "qai_wallet" not in app.blueprints:
        app.register_blueprint(bp)
    return app
