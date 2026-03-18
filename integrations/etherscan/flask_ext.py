from __future__ import annotations
import os
from flask import Blueprint, jsonify, request
from .etherscan_client import EtherscanClient
from .etherscan_v2 import EtherscanAPIError, EtherscanV2Client

bp = Blueprint("qai_etherscan", __name__)

EXPLORER_URLS = {
    "etherscan":  os.getenv("ETHERSCAN_API_URL",  "https://api.etherscan.io/api"),
    "arbiscan":   os.getenv("ARBISCAN_API_URL",   "https://api.arbiscan.io/api"),
    "optimism":   os.getenv("OPTIMISM_API_URL",   "https://api-optimistic.etherscan.io/api"),
    "bscscan":    os.getenv("BSCSCAN_API_URL",    "https://api.bscscan.com/api"),
    "snowscan":   os.getenv("SNOWSCAN_API_URL",   "https://api.snowscan.xyz/api"),
}

def _pick_v1():
    which = request.args.get("explorer","etherscan").lower()
    base  = EXPLORER_URLS.get(which, EXPLORER_URLS["etherscan"])
    return EtherscanClient(base_url=base)

def _pick_v2():
    chainid = request.args.get("chainid", type=int) or None
    base    = request.args.get("base") or os.getenv("ETHERSCAN_API_URL", "https://api.etherscan.io/api")
    return EtherscanV2Client(base_url=base, chain_id=chainid)


def _wants_v2() -> bool:
    return request.path.startswith("/v2/") or request.args.get("v2") == "1"


def _json_error(message: str, status_code: int = 400):
    return jsonify(ok=False, error=message), status_code


def _required_arg(*names: str) -> str:
    for name in names:
        value = request.args.get(name)
        if value:
            return value
    raise ValueError(f"missing required query parameter: {names[0]}")


def _paging_arg(primary: str, alias: str, default: int) -> int:
    return request.args.get(primary, type=int) or request.args.get(alias, type=int) or default


@bp.errorhandler(ValueError)
def handle_value_error(exc: ValueError):
    return _json_error(str(exc), 400)


@bp.errorhandler(EtherscanAPIError)
def handle_etherscan_error(exc: EtherscanAPIError):
    return _json_error(str(exc), 502)


@bp.get("/etherscan/balance")
def balance():
    addr = request.args.get("address") or os.getenv("ETH_ADDRESS", "").strip()
    if not addr:
        raise ValueError("address required")
    if _wants_v2():
        cli = _pick_v2()
        bal = cli.get_eth_balance(addr)
        return jsonify(ok=True, v="v2", address=addr, balance_wei=bal, balance_eth=str(bal / 10**18))
    cli = _pick_v1()
    bal = cli.get_balance_wei(addr)
    return jsonify(ok=True, v="v1", address=addr, balance_wei=bal, balance_eth=str(bal / 10**18))


@bp.get("/etherscan/txlist")
def txlist():
    addr = request.args.get("address") or os.getenv("ETH_ADDRESS", "").strip()
    if not addr:
        raise ValueError("address required")

    page = request.args.get("page", type=int) or 1
    offset = _paging_arg("offset", "limit", 10)
    sort = request.args.get("sort", default="asc")
    startblock = request.args.get("startblock", type=int) or 0
    endblock = request.args.get("endblock", type=int) or 99999999

    if _wants_v2():
        cli = _pick_v2()
        data = cli._request(
            {
                "module": "account",
                "action": "txlist",
                "address": addr,
                "startblock": startblock,
                "endblock": endblock,
                "page": page,
                "offset": offset,
                "sort": sort,
            }
        )
        return jsonify(ok=True, v="v2", result=data)

    cli = _pick_v1()
    txs = cli.get_txlist(
        addr,
        start_block=startblock,
        end_block=endblock,
        page=page,
        offset=offset,
        sort=sort,
    )
    return jsonify(ok=True, v="v1", address=addr, count=len(txs), result=txs)


@bp.get("/etherscan/logs")
def logs():
    addr = _required_arg("address")
    from_block = request.args.get("from", type=int)
    to_block = request.args.get("to", type=int)
    if from_block is None or to_block is None:
        raise ValueError("from and to required")

    topics = {
        "topic0": request.args.get("topic0"),
        "topic1": request.args.get("topic1"),
        "topic2": request.args.get("topic2"),
        "topic3": request.args.get("topic3"),
    }
    opr = request.args.get("opr")
    topic_ops = {}
    if topics["topic0"] and topics["topic1"] and opr in ("and", "or"):
        topic_ops["topic0_1_opr"] = opr
    if topics["topic1"] and topics["topic2"] and opr in ("and", "or"):
        topic_ops["topic1_2_opr"] = opr
    if topics["topic2"] and topics["topic3"] and opr in ("and", "or"):
        topic_ops["topic2_3_opr"] = opr

    if _wants_v2():
        cli = _pick_v2()
        params = {
            "module": "logs",
            "action": "getLogs",
            "address": addr,
            "fromBlock": from_block,
            "toBlock": to_block,
        }
        params.update({k: v for k, v in topics.items() if v})
        params.update(topic_ops)
        data = cli._request(params)
        return jsonify(ok=True, v="v2", result=data)

    cli = _pick_v1()
    rows = cli.get_logs(
        addr,
        from_block,
        to_block,
        topic0=topics["topic0"],
        topic1=topics["topic1"],
        topic2=topics["topic2"],
        topic3=topics["topic3"],
        topic0_1_opr=topic_ops.get("topic0_1_opr"),
        topic1_2_opr=topic_ops.get("topic1_2_opr"),
        topic2_3_opr=topic_ops.get("topic2_3_opr"),
    )
    return jsonify(ok=True, v="v1", address=addr, count=len(rows), result=rows)


@bp.get("/etherscan/erc20-transfers")
def erc20_transfers():
    q = request.args
    address = _required_arg("address")
    page = q.get("page", type=int) or 1
    offset = _paging_arg("offset", "limit", 10)
    sort = q.get("sort", default="desc")
    contractaddress = q.get("contractaddress")
    startblock = q.get("startblock", type=int) or 0
    endblock = q.get("endblock", type=int) or 99999999

    if _wants_v2():
        cli = _pick_v2()
        data = cli._request(
            {
                "module": "account",
                "action": "tokentx",
                "address": address,
                "contractaddress": contractaddress,
                "startblock": startblock,
                "endblock": endblock,
                "page": page,
                "offset": offset,
                "sort": sort,
            }
        )
        return jsonify(data)

    cli = _pick_v1()
    data = cli.erc20_transfers(
        address=address,
        page=page,
        offset=offset,
        sort=sort,
        contractaddress=contractaddress,
        startblock=startblock,
        endblock=endblock,
    )
    return jsonify(data)

@bp.get("/etherscan/erc721-transfers")
def erc721_transfers():
    q = request.args
    address = _required_arg("address")
    page = q.get("page", type=int) or 1
    offset = _paging_arg("offset", "limit", 10)
    sort = q.get("sort", default="desc")
    contractaddress = q.get("contractaddress")
    startblock = q.get("startblock", type=int) or 0
    endblock = q.get("endblock", type=int) or 99999999

    if _wants_v2():
        cli = _pick_v2()
        data = cli._request(
            {
                "module": "account",
                "action": "tokennfttx",
                "address": address,
                "contractaddress": contractaddress,
                "startblock": startblock,
                "endblock": endblock,
                "page": page,
                "offset": offset,
                "sort": sort,
            }
        )
        return jsonify(data)

    cli = _pick_v1()
    data = cli.erc721_transfers(
        address=address,
        page=page,
        offset=offset,
        sort=sort,
        contractaddress=contractaddress,
        startblock=startblock,
        endblock=endblock,
    )
    return jsonify(data)

@bp.get("/etherscan/erc1155-transfers")
def erc1155_transfers():
    q = request.args
    address = _required_arg("address")
    page = q.get("page", type=int) or 1
    offset = _paging_arg("offset", "limit", 10)
    sort = q.get("sort", default="desc")
    contractaddress = q.get("contractaddress")
    startblock = q.get("startblock", type=int) or 0
    endblock = q.get("endblock", type=int) or 99999999

    if _wants_v2():
        cli = _pick_v2()
        data = cli._request(
            {
                "module": "account",
                "action": "token1155tx",
                "address": address,
                "contractaddress": contractaddress,
                "startblock": startblock,
                "endblock": endblock,
                "page": page,
                "offset": offset,
                "sort": sort,
            }
        )
        return jsonify(data)

    cli = _pick_v1()
    data = cli.erc1155_transfers(
        address=address,
        page=page,
        offset=offset,
        sort=sort,
        contractaddress=contractaddress,
        startblock=startblock,
        endblock=endblock,
    )
    return jsonify(data)

@bp.get("/etherscan/tokenholders")
def tokenholders_list():
    cli = _pick_v2()
    data = cli.tokenholder_list(
        contractaddress=_required_arg("contractaddress", "contract"),
        page=request.args.get("page", type=int) or 1,
        offset=_paging_arg("offset", "limit", 10),
    )
    return jsonify(data)

@bp.get("/etherscan/tokenholders/count")
def tokenholders_count():
    cli = _pick_v2()
    data = cli.tokenholder_count(contractaddress=_required_arg("contractaddress", "contract"))
    return jsonify(data)


@bp.get("/etherscan/tokeninfo")
def tokeninfo():
    contractaddress = _required_arg("contractaddress", "contract")
    if _wants_v2():
        cli = _pick_v2()
        data = cli._request_with_module_fallback(
            action="tokeninfo",
            contractaddress=contractaddress.strip().lower(),
        )
        return jsonify(ok=True, v="v2", result=data)
    cli = _pick_v1()
    data = cli.token_info(contractaddress)
    return jsonify(ok=True, v="v1", result=data)


@bp.get("/etherscan/addresstokenbalance")
def addresstokenbalance():
    contractaddress = _required_arg("contractaddress", "contract")
    address = _required_arg("address")
    tag = request.args.get("tag", default="latest")
    if _wants_v2():
        cli = _pick_v2()
        value = cli.get_token_balance(address=address, contract_address=contractaddress)
        return jsonify(ok=True, v="v2", result=value, tag=tag)
    cli = _pick_v1()
    value = cli.address_token_balance(address=address, contractaddress=contractaddress, tag=tag)
    return jsonify(ok=True, v="v1", result=value, tag=tag)


@bp.post("/etherscan/verify")
def verify():
    data = request.form.to_dict() or (request.get_json(silent=True) or {})
    if not data:
        raise ValueError("verification payload required")
    required = ("contractaddress", "sourceCode", "compilerversion")
    missing = [key for key in required if not data.get(key)]
    if missing:
        raise ValueError(f"missing required fields: {', '.join(missing)}")

    chainid = request.args.get("chainid", type=int) or None
    if _wants_v2():
        cli = EtherscanClient(
            base_url=request.args.get("base") or os.getenv("ETHERSCAN_API_URL", "https://api.etherscan.io/api"),
            chain_id=chainid,
        )
        resp = cli.verify_source_code(**data)
        return jsonify(ok=True, v="v2", result=resp)

    cli = _pick_v1()
    resp = cli.verify_source_code(**data)
    return jsonify(ok=True, v="v1", result=resp)


@bp.get("/etherscan/verify/status")
def verify_status():
    guid = _required_arg("guid")
    chainid = request.args.get("chainid", type=int) or None
    if _wants_v2():
        cli = EtherscanClient(
            base_url=request.args.get("base") or os.getenv("ETHERSCAN_API_URL", "https://api.etherscan.io/api"),
            chain_id=chainid,
        )
        resp = cli.check_verify_status(guid=guid)
        return jsonify(ok=True, v="v2", result=resp)
    cli = _pick_v1()
    resp = cli.check_verify_status(guid=guid)
    return jsonify(ok=True, v="v1", result=resp)


def register_qai_etherscan(app):
    if "qai_etherscan" not in app.blueprints:
        app.register_blueprint(bp)
    if "v2.qai_etherscan" not in app.blueprints:
        app.register_blueprint(bp, url_prefix="/v2", name_prefix="v2")
    return app
