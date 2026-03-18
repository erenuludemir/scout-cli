from fastapi import FastAPI,HTTPException,Query
from pydantic import BaseModel
from web3 import Web3
import os,time
app=FastAPI()
RPC_URL=os.getenv("RPC_URL","");WALLET_ADDRESS=os.getenv("WALLET_ADDRESS","");PRIVATE_KEY=os.getenv("PRIVATE_KEY","")
if not RPC_URL: raise RuntimeError("RPC_URL required")
w3=Web3(Web3.HTTPProvider(RPC_URL))
WETH="0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";USDT="0xdAC17F958D2ee523a2206206994597C13D831ec7";ROUTER="0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D"
ERC20_ABI=[{"constant":True,"inputs":[],"name":"decimals","outputs":[{"name":"","type":"uint8"}],"type":"function"},{"constant":True,"inputs":[],"name":"symbol","outputs":[{"name":"","type":"string"}],"type":"function"},{"constant":True,"inputs":[{"name":"owner","type":"address"}],"name":"balanceOf","outputs":[{"name":"","type":"uint256"}],"type":"function"},{"constant":False,"inputs":[{"name":"spender","type":"address"},{"name":"value","type":"uint256"}],"name":"approve","outputs":[{"name":"","type":"bool"}],"type":"function"},{"constant":False,"inputs":[{"name":"to","type":"address"},{"name":"value","type":"uint256"}],"name":"transfer","outputs":[{"name":"","type":"bool"}],"type":"function"},{"constant":True,"inputs":[{"name":"owner","type":"address"},{"name":"spender","type":"address"}],"name":"allowance","outputs":[{"name":"","type":"uint256"}],"type":"function"}]
ROUTER_ABI=[{"name":"getAmountsOut","outputs":[{"name":"","type":"uint256[]"}],"inputs":[{"name":"amountIn","type":"uint256"},{"name":"path","type":"address[]"}],"stateMutability":"view","type":"function"},{"name":"swapExactETHForTokens","outputs":[{"name":"","type":"uint256[]"}],"inputs":[{"name":"amountOutMin","type":"uint256"},{"name":"path","type":"address[]"},{"name":"to","type":"address"},{"name":"deadline","type":"uint256"}],"stateMutability":"payable","type":"function"},{"name":"swapExactTokensForETH","outputs":[{"name":"","type":"uint256[]"}],"inputs":[{"name":"amountIn","type":"uint256"},{"name":"amountOutMin","type":"uint256"},{"name":"path","type":"address[]"},{"name":"to","type":"address"},{"name":"deadline","type":"uint256"}],"stateMutability":"nonpayable","type":"function"},{"name":"swapExactTokensForTokens","outputs":[{"name":"","type":"uint256[]"}],"inputs":[{"name":"amountIn","type":"uint256"},{"name":"amountOutMin","type":"uint256"},{"name":"path","type":"address[]"},{"name":"to","type":"address"},{"name":"deadline","type":"uint256"}],"stateMutability":"nonpayable","type":"function"}]
router=w3.eth.contract(address=Web3.to_checksum_address(ROUTER),abi=ROUTER_ABI)
def erc20(a):return w3.eth.contract(address=Web3.to_checksum_address(a),abi=ERC20_ABI)
def to_wei(x,d):return int(round(float(x)*(10**d)))
def from_wei(x,d):return float(x)/(10**d)
def fees():
    gp=int(w3.eth.gas_price)
    return {"maxFeePerGas":gp*2,"maxPriorityFeePerGas":max(int(gp*0.1),w3.to_wei(1,"gwei"))}
@app.get("/health")
def health():return {"ok":True,"chainId":w3.eth.chain_id,"ts":int(time.time())}
@app.get("/balance")
def balance(address:str=Query(...),token:str=Query("ETH")):
    addr=Web3.to_checksum_address(address)
    if token.upper()=="ETH":
        b=w3.eth.get_balance(addr);return {"token":"ETH","balance_wei":int(b),"balance":float(w3.from_wei(b,"ether"))}
    t=Web3.to_checksum_address(USDT if token.upper()=="USDT" else token)
    c=erc20(t);dec=c.functions.decimals().call()
    try:sym=c.functions.symbol().call()
    except:sym="TOKEN"
    bal=c.functions.balanceOf(addr).call()
    return {"token":sym,"address":t,"decimals":int(dec),"balance_raw":int(bal),"balance":from_wei(bal,dec)}
class TransferBody(BaseModel):to:str;amount:str;token:str="ETH"
@app.post("/transfer")
def transfer(b:TransferBody):
    if not PRIVATE_KEY or not WALLET_ADDRESS: raise HTTPException(400,"WALLET_ADDRESS/PRIVATE_KEY missing")
    sender=Web3.to_checksum_address(WALLET_ADDRESS);to=Web3.to_checksum_address(b.to)
    if b.token.upper()=="ETH":
        value=w3.to_wei(b.amount,"ether")
        tx={"from":sender,"to":to,"value":value,"nonce":w3.eth.get_transaction_count(sender),"chainId":w3.eth.chain_id}|fees()
        tx["gas"]=w3.eth.estimate_gas(tx)
        sig=w3.eth.account.sign_transaction(tx,PRIVATE_KEY)
        txh=w3.eth.send_raw_transaction(sig.rawTransaction).hex()
        return {"ok":True,"tx":txh}
    token_addr=Web3.to_checksum_address(USDT if b.token.upper()=="USDT" else b.token)
    c=erc20(token_addr);dec=c.functions.decimals().call();amt=to_wei(b.amount,dec)
    tx=c.functions.transfer(to,amt).build_transaction({"from":sender,"nonce":w3.eth.get_transaction_count(sender),"chainId":w3.eth.chain_id}|fees())
    tx["gas"]=w3.eth.estimate_gas(tx)
    sig=w3.eth.account.sign_transaction(tx,PRIVATE_KEY)
    txh=w3.eth.send_raw_transaction(sig.rawTransaction).hex()
    return {"ok":True,"tx":txh}
class SwapBody(BaseModel):from_token:str;to_token:str;amount_in:str;slippage_bps:int=50
@app.post("/swap")
def swap(b:SwapBody):
    if not PRIVATE_KEY or not WALLET_ADDRESS: raise HTTPException(400,"WALLET_ADDRESS/PRIVATE_KEY missing")
    sender=Web3.to_checksum_address(WALLET_ADDRESS)
    ft=b.from_token.upper();tt=b.to_token.upper()
    faddr=Web3.to_checksum_address(WETH if ft=="ETH" else (USDT if ft=="USDT" else b.from_token))
    taddr=Web3.to_checksum_address(WETH if tt=="ETH" else (USDT if tt=="USDT" else b.to_token))
    path=[faddr,taddr] if (faddr==WETH or taddr==WETH) else [faddr,WETH,taddr]
    if ft=="ETH":
        amt_in=w3.to_wei(b.amount_in,"ether")
    else:
        fcon=erc20(faddr);fdec=fcon.functions.decimals().call();amt_in=to_wei(b.amount_in,fdec);allow=fcon.functions.allowance(sender,ROUTER).call()
        if allow<amt_in:
            txa=fcon.functions.approve(ROUTER,amt_in).build_transaction({"from":sender,"nonce":w3.eth.get_transaction_count(sender),"chainId":w3.eth.chain_id}|fees());txa["gas"]=w3.eth.estimate_gas(txa);sa=w3.eth.account.sign_transaction(txa,PRIVATE_KEY);w3.eth.send_raw_transaction(sa.rawTransaction)
    amounts=router.functions.getAmountsOut(amt_in,path).call()
    out_min=amounts[-1]*(10000-b.slippage_bps)//10000
    deadline=int(time.time())+900
    nonce=w3.eth.get_transaction_count(sender)
    if ft=="ETH":
        tx=router.functions.swapExactETHForTokens(out_min,path,sender,deadline).build_transaction({"from":sender,"value":amt_in,"nonce":nonce,"chainId":w3.eth.chain_id}|fees())
    elif tt=="ETH":
        tx=router.functions.swapExactTokensForETH(amt_in,out_min,path,sender,deadline).build_transaction({"from":sender,"nonce":nonce,"chainId":w3.eth.chain_id}|fees())
    else:
        tx=router.functions.swapExactTokensForTokens(amt_in,out_min,path,sender,deadline).build_transaction({"from":sender,"nonce":nonce,"chainId":w3.eth.chain_id}|fees())
    tx["gas"]=w3.eth.estimate_gas(tx)
    s=w3.eth.account.sign_transaction(tx,PRIVATE_KEY)
    txh=w3.eth.send_raw_transaction(s.rawTransaction).hex()
    return {"ok":True,"tx":txh,"amount_out_min":int(out_min)}
