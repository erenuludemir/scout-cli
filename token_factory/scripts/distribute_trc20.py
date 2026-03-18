#!/usr/bin/env python3
from __future__ import annotations

import json
import sys
from pathlib import Path

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from token_factory.config import TokenFactoryConfig
from token_factory.scripts.common import read_distribution_csv


def main() -> None:
    from tronpy import Tron
    from tronpy.keys import PrivateKey
    from tronpy.providers import HTTPProvider

    root = Path(__file__).resolve().parents[2]
    config = TokenFactoryConfig(root=root)

    if not config.tron_private_key:
        raise SystemExit("MISSING:TRON_PRIVATE_KEY")
    if not config.distribution_csv:
        raise SystemExit("MISSING:TOKEN_DISTRIBUTION_CSV")

    manifest_path = config.manifests_dir / f"trc20_deploy_{config.token_symbol.lower()}.json"
    build_path = config.build_dir / "QuantumTRC20Token.json"
    if not manifest_path.exists():
        raise SystemExit(f"MISSING:{manifest_path}")
    if not build_path.exists():
        raise SystemExit(f"MISSING:{build_path}")

    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    rows = read_distribution_csv(config.distribution_csv)
    if not rows:
        raise SystemExit("EMPTY_DISTRIBUTION")

    client = Tron(provider=HTTPProvider(endpoint_uri=config.tron_provider_url))
    private_key = PrivateKey(bytes.fromhex(config.tron_private_key))
    contract = client.get_contract(manifest["contract_address"])

    recipients = [row["address"] for row in rows]
    amounts = [int(row["amount"]) for row in rows]

    txn = (
        contract.functions.batchTransfer(recipients, amounts)
        .with_owner(private_key.public_key.to_base58check_address())
        .fee_limit(config.tron_fee_limit)
        .build()
        .sign(private_key)
        .broadcast()
        .wait()
    )

    out = {
        "ok": True,
        "chain_type": "trc20",
        "token_symbol": config.token_symbol,
        "contract_address": manifest["contract_address"],
        "distribution_csv": str(config.distribution_csv),
        "recipient_count": len(recipients),
        "whole_units_total": sum(amounts),
        "tx_hash": txn.get("id") or txn.get("txid", ""),
    }
    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
