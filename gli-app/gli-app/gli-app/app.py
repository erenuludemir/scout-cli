import os
from flask import Flask, request, jsonify
from dotenv import load_dotenv
from appmod.etherscan_v2_client import EtherscanV2Client

load_dotenv()

ETHERSCAN_API_KEY = os.getenv("ETHERSCAN_API_KEY", "YourApiKeyToken")
CHAIN_ID = int(os.getenv("CHAIN_ID", "1"))

app = Flask(__name__)
client = EtherscanV2Client(api_key=ETHERSCAN_API_KEY, chain_id=CHAIN_ID)

@app.get("/health")
def health():
    return jsonify(status="ok", chain_id=CHAIN_ID)

@app.get("/")
def index():
    return jsonify(
        message="GLI Etherscan v2 proxy",
        health="/health",
        examples={
            "balance": f"/api/balance/0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae",
            "txlist": f"/api/txlist?address=0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC&offset=2",
            "tokentx": f"/api/tokentx?address=0x4e83362442b8d1bec281594cea3050c8eb01311c&contractaddress=0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2&offset=2",
            "fundedby": f"/api/fundedby?address=0x8f5419c8797cbdecaf3f2f1910d192f4306d527d",
            "getminedblocks": f"/api/getminedblocks?address=0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b&blocktype=blocks&offset=3",
        },
        note="ETHERSCAN_API_KEY .env içinde ayarlanmalı"
    )

@app.get("/api/balance/<address>")
def api_balance(address):
    tag = request.args.get("tag", "latest")
    return jsonify(client.balance(address, tag))

@app.get("/api/balancemulti")
def api_balancemulti():
    addresses = request.args.get("address", "")
    addrs = [a.strip() for a in addresses.split(",") if a.strip()]
    if not addrs:
        return jsonify({"status":"0","message":"address param required"}), 400
    return jsonify(client.balancemulti(addrs, request.args.get("tag","latest")))

@app.get("/api/txlist")
def api_txlist():
    q = request.args
    return jsonify(client.txlist(
        q.get("address",""),
        int(q.get("startblock",0)),
        int(q.get("endblock",99999999)),
        int(q.get("page",1)),
        int(q.get("offset",10)),
        q.get("sort","asc")
    ))

@app.get("/api/txlistinternal/address")
def api_txlistinternal_addr():
    q = request.args
    return jsonify(client.txlistinternal_by_address(
        q.get("address",""),
        int(q.get("startblock",0)),
        int(q.get("endblock",99999999)),
        int(q.get("page",1)),
        int(q.get("offset",10)),
        q.get("sort","asc")
    ))

@app.get("/api/txlistinternal/tx")
def api_txlistinternal_tx():
    txhash = request.args.get("txhash","")
    return jsonify(client.txlistinternal_by_txhash(txhash))

@app.get("/api/txlistinternal/blockrange")
def api_txlistinternal_blockrange():
    q = request.args
    return jsonify(client.txlistinternal_by_blockrange(
        int(q.get("startblock",0)), int(q.get("endblock",0)),
        int(q.get("page",1)), int(q.get("offset",10)), q.get("sort","asc")
    ))

@app.get("/api/tokentx")
def api_tokentx():
    q = request.args
    return jsonify(client.tokentx(
        q.get("address"), q.get("contractaddress"),
        int(q.get("page",1)), int(q.get("offset",10)),
        int(q.get("startblock",0)), int(q.get("endblock",99999999)), q.get("sort","asc")
    ))

@app.get("/api/tokennfttx")
def api_tokennfttx():
    q = request.args
    return jsonify(client.tokennfttx(
        q.get("address"), q.get("contractaddress"),
        int(q.get("page",1)), int(q.get("offset",10)),
        int(q.get("startblock",0)), int(q.get("endblock",99999999)), q.get("sort","asc")
    ))

@app.get("/api/token1155tx")
def api_token1155tx():
    q = request.args
    return jsonify(client.token1155tx(
        q.get("address"), q.get("contractaddress"),
        int(q.get("page",1)), int(q.get("offset",10)),
        int(q.get("startblock",0)), int(q.get("endblock",99999999)), q.get("sort","asc")
    ))

@app.get("/api/fundedby")
def api_fundedby():
    address = request.args.get("address","")
    return jsonify(client.fundedby(address))

@app.get("/api/getminedblocks")
def api_getminedblocks():
    q = request.args
    return jsonify(client.getminedblocks(q.get("address",""), q.get("blocktype","blocks"),
                                        int(q.get("page",1)), int(q.get("offset",10))))

if __name__ == "__main__":
    app.run("0.0.0.0", 5000)
