from flask import Flask, request, jsonify
from web3 import Web3
import os

app = Flask(__name__)
w3 = Web3(Web3.HTTPProvider(os.getenv("RPC_URL")))
contract_address = Web3.to_checksum_address(os.getenv("USDT_CONTRACT_ADDRESS"))
wallet_address = Web3.to_checksum_address(os.getenv("WALLET_ADDRESS"))
private_key = os.getenv("PRIVATE_KEY")

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "ok",
        "network": "ethereum-mainnet",
        "wallet": wallet_address,
        "usdt_contract": contract_address
    })

@app.route("/transfer", methods=["POST"])
def transfer():
    data = request.json
    if not data or not data.get("to") or not data.get("amount"):
        return jsonify({"status": "error", "message": "recipient/amount required"}), 400
    to = Web3.to_checksum_address(data.get("to"))
    amount = int(float(data.get("amount")) * 10**6)

    contract = w3.eth.contract(address=contract_address, abi=[{
        "constant": False,
        "inputs": [{"name": "_to", "type": "address"}, {"name": "_value", "type": "uint256"}],
        "name": "transfer",
        "outputs": [{"name": "", "type": "bool"}],
        "type": "function"
    }])

    nonce = w3.eth.get_transaction_count(wallet_address)
    txn = contract.functions.transfer(to, amount).build_transaction({
        "chainId": 1,
        "gas": 100000,
        "gasPrice": w3.to_wei("35", "gwei"),
        "nonce": nonce
    })

    signed_txn = w3.eth.account.sign_transaction(txn, private_key=private_key)
    tx_hash = w3.eth.send_raw_transaction(signed_txn.rawTransaction)
    return jsonify({"tx_hash": w3.to_hex(tx_hash)})
    
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("HOST_PORT", 5002)))
