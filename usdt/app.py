from __future__ import annotations

import asyncio
import os
from typing import Any

from dotenv import load_dotenv
from flask import Flask, jsonify, request

try:
    from web3 import Web3
except Exception:  # pragma: no cover - preview mode can run without host dependency
    Web3 = None

try:
    from integrations.etherscan.flask_ext import bp
except Exception:  # pragma: no cover - standalone usdt image does not ship repo-wide extras
    bp = None

try:
    from etherscan_v2_client import EtherscanV2Client
except Exception:  # pragma: no cover - optional network helper
    EtherscanV2Client = None


load_dotenv(override=False)

NETWORK = "ethereum-mainnet"
USDT_CONTRACT = "0xdAC17F958D2ee523a2206206994597C13D831ec7"
ERC20_ABI = [
    {
        "constant": False,
        "inputs": [{"name": "_to", "type": "address"}, {"name": "_value", "type": "uint256"}],
        "name": "transfer",
        "outputs": [{"name": "", "type": "bool"}],
        "type": "function",
    },
    {
        "constant": True,
        "inputs": [{"name": "_owner", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"name": "balance", "type": "uint256"}],
        "type": "function",
    },
    {
        "constant": True,
        "inputs": [],
        "name": "decimals",
        "outputs": [{"name": "", "type": "uint8"}],
        "type": "function",
    },
    {
        "constant": True,
        "inputs": [],
        "name": "symbol",
        "outputs": [{"name": "", "type": "string"}],
        "type": "function",
    },
]


class RuntimeState:
    def __init__(
        self,
        *,
        infura_project_id: str = "",
        rpc_url: str = "",
        sender: str | None = None,
        private_key: str = "",
        dry_run: bool = True,
        configuration_errors: list[str] | None = None,
        w3: Any | None = None,
        erc20: Any | None = None,
    ):
        self.infura_project_id = infura_project_id
        self.rpc_url = rpc_url
        self.sender = sender
        self.private_key = private_key
        self.dry_run = dry_run
        self.configuration_errors = list(configuration_errors or [])
        self.w3 = w3
        self.erc20 = erc20

    @property
    def rpc_ready(self) -> bool:
        return self.w3 is not None

    @property
    def signer_ready(self) -> bool:
        return bool(self.sender and self.private_key)

    @property
    def preview_only(self) -> bool:
        return not (self.rpc_ready and self.signer_ready) or self.dry_run

    @property
    def execution_enabled(self) -> bool:
        return self.rpc_ready and self.signer_ready and not self.dry_run


async def _get_eth_usd_async():
    if EtherscanV2Client is None:
        return None
    try:
        async with EtherscanV2Client(chain_id=1) as cli:
            return await cli.get_eth_price()
    except Exception:
        return None


def get_eth_usd():
    try:
        return asyncio.run(_get_eth_usd_async())
    except Exception:
        return None


def _is_placeholder(value: str) -> bool:
    lowered = value.strip().lower()
    return not lowered or "placeholder" in lowered or lowered in {"changeme", "your_infura_project_id"}


def _build_rpc_url(infura_project_id: str, direct_url: str) -> str:
    if direct_url and not _is_placeholder(direct_url):
        return direct_url
    if infura_project_id and not _is_placeholder(infura_project_id):
        return f"https://mainnet.infura.io/v3/{infura_project_id}"
    return ""


def _classify_upstream_error(exc: Exception) -> tuple[str, int]:
    message = str(exc)
    lowered = message.lower()
    if "401" in lowered or "403" in lowered or "unauthorized" in lowered or "forbidden" in lowered:
        return "rpc provider authentication failed", 502
    if "timed out" in lowered or "timeout" in lowered:
        return "rpc provider timeout", 504
    if "name or service not known" in lowered or "temporary failure in name resolution" in lowered:
        return "rpc provider unavailable", 502
    return message, 500


def _build_runtime_state() -> RuntimeState:
    direct_rpc_url = os.getenv("INFURA_URL", "").strip()
    state = RuntimeState(
        infura_project_id=os.getenv("INFURA_PROJECT_ID", "").strip(),
        rpc_url="",
        private_key=os.getenv("ETH_PRIVATE_KEY", "").strip(),
        dry_run=os.getenv("GLI_DRY_RUN", "1") != "0",
    )
    sender_raw = os.getenv("ETH_SENDER_ADDRESS", "").strip()

    state.rpc_url = _build_rpc_url(state.infura_project_id, direct_rpc_url)
    if not state.rpc_url:
        state.configuration_errors.append("INFURA_URL/INFURA_PROJECT_ID missing or placeholder")
    if not sender_raw:
        state.configuration_errors.append("ETH_SENDER_ADDRESS missing")
    if not state.private_key:
        state.configuration_errors.append("ETH_PRIVATE_KEY missing")

    if Web3 is None:
        state.configuration_errors.append("web3 dependency unavailable")
        return state

    if state.rpc_url:
        state.w3 = Web3(Web3.HTTPProvider(state.rpc_url))

    if sender_raw:
        try:
            state.sender = Web3.to_checksum_address(sender_raw)
        except ValueError:
            state.configuration_errors.append("ETH_SENDER_ADDRESS invalid")

    if state.w3 is not None:
        try:
            usdt = Web3.to_checksum_address(USDT_CONTRACT)
            state.erc20 = state.w3.eth.contract(address=usdt, abi=ERC20_ABI)
        except Exception as exc:  # pragma: no cover - defensive
            state.configuration_errors.append(f"USDT contract setup failed: {exc}")

    return state


def _service_payload(state: RuntimeState) -> dict[str, Any]:
    return {
        "ok": True,
        "status": "ok",
        "service": "usdt",
        "network": NETWORK,
        "sender": state.sender,
        "mode": "preview" if state.preview_only else "live",
        "execution_enabled": state.execution_enabled,
        "rpc_ready": state.rpc_ready,
        "signer_ready": state.signer_ready,
        "dry_run": state.dry_run,
        "etherscan_enabled": bp is not None,
        "rpc_configured": bool(state.rpc_url),
        "configuration_errors": state.configuration_errors,
    }


def _runtime_error(state: RuntimeState, action: str):
    missing = ", ".join(state.configuration_errors) or "runtime unavailable"
    return (
        jsonify(
            {
                "status": "error",
                "message": f"{action} unavailable while service is in preview mode: {missing}",
                "execution_enabled": False,
            }
        ),
        503,
    )


def create_app() -> Flask:
    app = Flask(__name__)
    state = _build_runtime_state()
    app.config["QAI_RUNTIME_STATE"] = state

    @app.get("/")
    def root():
        return jsonify(_service_payload(state))

    @app.get("/health")
    def health():
        return jsonify(_service_payload(state))

    @app.post("/estimate")
    def estimate():
        if not (state.rpc_ready and state.signer_ready and state.erc20 is not None):
            return _runtime_error(state, "estimate")

        try:
            data = request.get_json(force=True) or {}
            recipient_raw = data.get("recipient")
            amount_6 = int(data.get("amount", 0))
            if not recipient_raw or amount_6 <= 0:
                return jsonify({"status": "error", "message": "recipient/amount required"}), 400

            recipient = Web3.to_checksum_address(recipient_raw)
            transfer_fn = state.erc20.functions.transfer(recipient, amount_6)
            nonce = state.w3.eth.get_transaction_count(state.sender)
            gas_price = state.w3.eth.gas_price
            try:
                gas_estimate = transfer_fn.estimate_gas({"from": state.sender})
            except Exception:
                gas_estimate = 60000

            tx = transfer_fn.build_transaction(
                {
                    "chainId": 1,
                    "from": state.sender,
                    "nonce": nonce,
                    "gas": int(gas_estimate),
                    "gasPrice": gas_price,
                }
            )

            fee_wei = gas_price * gas_estimate
            fee_eth = Web3.from_wei(fee_wei, "ether")
            eth_usd = get_eth_usd()

            return jsonify(
                {
                    "status": "ok",
                    "chain": NETWORK,
                    "token": "USDT",
                    "decimals": 6,
                    "from": state.sender,
                    "to": recipient,
                    "amount_usdt_6": amount_6,
                    "amount_usdt_human": amount_6 / 1_000_000.0,
                    "gas_price_wei": int(gas_price),
                    "gas_used_estimate": int(gas_estimate),
                    "fee_eth": float(fee_eth),
                    "eth_usd": eth_usd,
                    "fee_usd_estimate": (float(fee_eth) * eth_usd) if eth_usd else None,
                }
            )
        except ValueError as exc:
            return jsonify({"status": "error", "message": str(exc)}), 400
        except Exception as exc:
            return jsonify({"status": "error", "message": str(exc)}), 500

    @app.post("/transfer")
    def transfer():
        if not (state.rpc_ready and state.signer_ready and state.erc20 is not None):
            return _runtime_error(state, "transfer")

        try:
            data = request.get_json(force=True) or {}
            recipient_raw = data.get("recipient")
            amount_6 = int(data.get("amount", 0))
            if not recipient_raw or amount_6 <= 0:
                return jsonify({"status": "error", "message": "recipient/amount required"}), 400

            recipient = Web3.to_checksum_address(recipient_raw)
            nonce = state.w3.eth.get_transaction_count(state.sender)
            gas_price = state.w3.eth.gas_price
            built = state.erc20.functions.transfer(recipient, amount_6).build_transaction(
                {
                    "chainId": 1,
                    "from": state.sender,
                    "nonce": nonce,
                    "gas": 120000,
                    "gasPrice": gas_price,
                }
            )
            signed = state.w3.eth.account.sign_transaction(
                built,
                private_key=state.private_key,
            )
            raw_hex = signed.rawTransaction.hex()
            hash_hex = Web3.to_hex(Web3.keccak(signed.rawTransaction))

            if state.dry_run:
                return jsonify(
                    {
                        "status": "preview",
                        "tx_hash_computed": hash_hex,
                        "raw_tx": raw_hex,
                        "gas_price_wei": int(gas_price),
                        "gas_limit": int(built.get("gas", 0)),
                        "fee_estimate_eth": float(
                            Web3.from_wei(gas_price * built.get("gas", 0), "ether")
                        ),
                        "note": "Set GLI_DRY_RUN=0 to broadcast",
                    }
                )

            tx_hash = state.w3.eth.send_raw_transaction(signed.rawTransaction)
            receipt = state.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=180)
            return jsonify(
                {
                    "status": "sent",
                    "tx_hash": Web3.to_hex(tx_hash),
                    "gas_used": int(receipt.gasUsed),
                    "block": int(receipt.blockNumber),
                }
            )
        except ValueError as exc:
            return jsonify({"status": "error", "message": str(exc)}), 400
        except Exception as exc:
            return jsonify({"status": "error", "message": str(exc)}), 500

    @app.post("/balance")
    def balance():
        if not (state.rpc_ready and state.erc20 is not None):
            return _runtime_error(state, "balance")

        try:
            data = request.get_json(silent=True) or {}
            addr_raw = data.get("address") or state.sender
            if not addr_raw:
                return jsonify({"status": "error", "message": "address required"}), 400

            address = Web3.to_checksum_address(addr_raw)
            eth_bal = state.w3.from_wei(state.w3.eth.get_balance(address), "ether")
            usdt_bal = state.erc20.functions.balanceOf(address).call()
            return jsonify(
                {
                    "status": "ok",
                    "address": address,
                    "eth": float(eth_bal),
                    "usdt_6": int(usdt_bal),
                    "usdt_human": int(usdt_bal) / 1_000_000.0,
                }
            )
        except ValueError as exc:
            return jsonify({"status": "error", "message": str(exc)}), 400
        except Exception as exc:
            message, status_code = _classify_upstream_error(exc)
            return jsonify({"status": "error", "message": message}), status_code

    if bp is not None:
        app.register_blueprint(bp)
    return app


app = create_app()


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
