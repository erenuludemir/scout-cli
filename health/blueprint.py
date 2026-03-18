from __future__ import annotations
import os
from flask import Blueprint, jsonify

bp_health = Blueprint("health", __name__)


def build_health_payload() -> dict:
    sender = os.getenv("ETH_SENDER_ADDRESS") or os.getenv("WALLET_ADDRESS")
    return {
        "ok": True,
        "status": "ok",
        "network": os.getenv("ETH_NETWORK", "ethereum-mainnet"),
        "sender": sender,
        "wallet": sender,
        "usdt": os.getenv("USDT_CONTRACT_ADDRESS"),
        "usdt_contract": os.getenv("USDT_CONTRACT_ADDRESS"),
    }


@bp_health.get("/health")
def health():
    return jsonify(build_health_payload()), 200


@bp_health.get("/healthz")
def healthz():
    return jsonify(build_health_payload()), 200
