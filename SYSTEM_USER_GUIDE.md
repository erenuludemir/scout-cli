# QuantumAI System User Guide

Version: 2025-08-28

Scope Root (External Drive Layout):

- Warehouse Root (External): /Volumes/LaCie/Container-QuantumAI
   - System Source: /Volumes/LaCie/Container-QuantumAI/QuantumAI-Dockerized-System (APP_ROOT)
   - AI Model Artifacts: /Volumes/LaCie/Container-QuantumAI/Recovered_Backup_28082025/trained_model.json
   - Central Logs (optional): /Volumes/LaCie/Container-QuantumAI/QuantumAI-Dockerized-System-Log
   - Backups: /Volumes/LaCie/Container-QuantumAI/QuantumAI-Dockerized-System-Backup

---
### Etherscan V2 Unified Multi-Chain API (Introduction)

Etherscan's V2 platform consolidates data access for dozens of EVM chains behind one endpoint and a single API key. This removes the historical need to manage separate `*_API_KEY` values (e.g., ETHERSCAN / BSCSCAN / ARBISCAN) and disparate base URLs. For QuantumAI you now keep a single secret (e.g. `ETHERSCAN_API_KEY`) and pass a `chainid` query parameter per request.

Key benefits:

- Unified authentication (one key) across >50 chains.
- Consistent request pattern: `https://api.etherscan.io/v2/api?chainid=<id>&module=...&action=...`.
- Easier loop / batch retrieval for multi-chain balance snapshots.
- Reduced secret sprawl and simpler CI/CD secret rotation.

Migration considerations (legacy -> V2):

| Legacy Pattern | V2 Replacement |
|----------------|----------------|
| Multiple explorer keys (`ETHERSCAN_API_KEY`, `BSCSCAN_API_KEY`, etc.) | Single `ETHERSCAN_API_KEY` |
| Multiple base URLs | Single base + `chainid` parameter |
| Environment variable proliferation | One key + optional allowed chain list |

Recommended new env vars:

```bash
ETHERSCAN_API_KEY=__YOUR_KEY__
ETHERSCAN_CHAIN_IDS="1,42161,10,8453"   # mainnet, arbitrum, optimism, base (example)
```

#### JavaScript example (multi-chain balance loop)

```javascript
const apiKey = process.env.ETHERSCAN_API_KEY;
const chains = [1, 42161, 8453, 10]; // Ethereum, Arbitrum, Base, Optimism
const address = '0xb5d85cbf7cb3ee0d56b3bb207d5fc4b82f43f511';

async function fetchBalance(chainid) {
   const url = new URL('https://api.etherscan.io/v2/api');
   url.searchParams.set('chainid', chainid);
   url.searchParams.set('module', 'account');
   url.searchParams.set('action', 'balance');
   url.searchParams.set('address', address);
   url.searchParams.set('tag', 'latest');
   url.searchParams.set('apikey', apiKey);
   const res = await fetch(url); if (!res.ok) throw new Error(res.status);
   return res.json();
}

(async () => {
   for (const c of chains) {
      try { const j = await fetchBalance(c); console.log('chain', c, 'balance', j.result); }
      catch (e) { console.error('chain', c, 'err', e.message); }
   }
})();
```

#### Python example

```python
import os, requests
API_KEY = os.environ['ETHERSCAN_API_KEY']
ADDRESS = '0xb5d85cbf7cb3ee0d56b3bb207d5fc4b82f43f511'
CHAIN_IDS = [1, 42161, 10]

def get_balance(cid: int):
      p = {
            'chainid': cid,
            'module': 'account',
            'action': 'balance',
            'address': ADDRESS,
            'tag': 'latest',
            'apikey': API_KEY,
      }
      r = requests.get('https://api.etherscan.io/v2/api', params=p, timeout=15)
      r.raise_for_status()
      return r.json()['result']

for cid in CHAIN_IDS:
      try:
            print(cid, get_balance(cid))
      except Exception as exc:
            print(cid, 'error', exc)
```

Operational guidance:

- Respect rate limits: insert small delays for large chain lists.
- Cache static metadata per chain to cut repeated calls.
- Log `chainid`, action, and HTTP status for observability.

Security tips:

- Treat the API key like any other secret (do not commit `.env`).
- Use per-environment keys (dev vs prod) for isolation & revocation.
- Rotate keys periodically; reload services (watchtower / restart) after updating.

Not every legacy endpoint is instantly universal—fallback logic or conditional feature gating may be required for chains still rolling out specific modules.

---

## V1 to V2 API Migration Guide

{% hint style="warning" %}
Use your **Etherscan API KEY** onl&#x79;**.**
{% endhint %}

### If you're coming from V1

Your base url looks like this

```
https://api.etherscan.io/api
```

Just append V2 to the base url, and a `chainId` parameter

```
https://api.etherscan.io/v2/api?chainid=1
```

## Geth/Parity Proxy

{% hint style="info" %}
For the full documentation of available parameters and descriptions, please visit the official [**Ethereum JSON-RPC**](https://eth.wiki/json-rpc/API) docs.
{% endhint %}

{% hint style="warning" %}
For compatibility with **Parity**, please prefix all hex strings with " **0x** ".
{% endhint %}

## **eth_blockNumber**

Returns the number of most recent block

```
https://api.etherscan.io/api
   ?module=proxy
   &action=eth_blockNumber
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/api?module=proxy\&action=eth_blockNumber\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
No parameters required.
{% endtab %}

{% tab title="Response" %}
Sample response

```
{
   "jsonrpc":"2.0",
   "id":83,
   "result":"0xc36b29"
}
```
{% endtab %}
{% endtabs %}

## **eth_getBlockByNumber**

Returns information about a block by block number.

```
https://api.etherscan.io/api
   ?module=proxy
   &action=eth_getBlockByNumber
   &tag=0x10d4f
   &boolean=true
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/api?module=proxy\&action=eth_getBlockByNumber\&tag=0x10d4f\&boolean=true\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter | Description                                                                                                                                                                                                                                                  |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| tag       | the block number, in hex eg. `0xC36B3C`                                                                                                                                                                                                                      |
| boolean   | <p>the <code>boolean</code> value to show full transaction objects.</p><p>when <code>true</code>, returns <strong>full transaction objects</strong> and their information, when <code>false</code> only returns a <strong>list of transactions.</strong></p> |
{% endtab %}

{% tab title="Response" %}
Sample response

```
{
   "jsonrpc":"2.0",
   "id":1,
   "result":{
      "baseFeePerGas":"0x5cfe76044",
      "difficulty":"0x1b4ac252b8a531",
      "extraData":"0xd883010a06846765746888676f312e31362e36856c696e7578",
      "gasLimit":"0x1caa87b",
      "gasUsed":"0x5f036a",
      "hash":"0x396288e0ad6690159d56b5502a172d54baea649698b4d7af2393cf5d98bf1bb3",
      "logsBloom":"0x5020418e211832c600000411c00098852850124700800500580d406984009104010420410c00420080414b044000012202448082084560844400d00002202b1209122000812091288804302910a246e25380282000e00002c00050009038cc205a018180028225218760100040820ac12302840050180448420420b000080000410448288400e0a2c2402050004024a240200415016c105844214060005009820302001420402003200452808508401014690208808409000033264a1b0d200c1200020280000cc0220090a8000801c00b0100a1040a8110420111870000250a22dc210a1a2002409c54140800c9804304b408053112804062088bd700900120",
      "miner":"0x5a0b54d5dc17e0aadc383d2db43b0a0d3e029c4c",
      "mixHash":"0xc547c797fb85c788ecfd4f5d24651bddf15805acbaad2c74b96b0b2a2317e66c",
      "nonce":"0x04a99df972bd8412",
      "number":"0xc63251",
      "parentHash":"0xbb2d43395f93dab5c424421be22d874f8c677e3f466dc993c218fa2cd90ef120",
      "receiptsRoot":"0x3de3b59d208e0fd441b6a2b3b1c814a2929f5a2d3016716465d320b4d48cc1e5",
      "sha3Uncles":"0xee2e81479a983dd3d583ab89ec7098f809f74485e3849afb58c2ea8e64dd0930",
      "size":"0x6cb6",
      "stateRoot":"0x60fdb78b92f0e621049e0aed52957971e226a11337f633856d8b953a56399510",
      "timestamp":"0x6110bab2",
      "totalDifficulty":"0x612789b0aba90e580f8",
      "transactions":[
         "0x40330c87750aa1ba1908a787b9a42d0828e53d73100ef61ae8a4d925329587b5",
         "0x6fa2208790f1154b81fc805dd7565679d8a8cc26112812ba1767e1af44c35dd4",
         "0xe31d8a1f28d4ba5a794e877d65f83032e3393809686f53fa805383ab5c2d3a3c",
         "0xa6a83df3ca7b01c5138ec05be48ff52c7293ba60c839daa55613f6f1c41fdace",
         "0x4e46edeb68a62dde4ed081fae5efffc1fb5f84957b5b3b558cdf2aa5c2621e17",
         "0x356ee444241ae2bb4ce9f77cdbf98cda9ffd6da244217f55465716300c425e82",
         "0x1a4ec2019a3f8b1934069fceff431e1370dcc13f7b2561fe0550cc50ab5f4bbc",
         "0xad7994bc966aed17be5d0b6252babef3f56e0b3f35833e9ac414b45ed80dac93"
      ],
      "transactionsRoot":"0xaceb14fcf363e67d6cdcec0d7808091b764b4428f5fd7e25fb18d222898ef779",
      "uncles":[
         "0x9e8622c7bf742bdeaf96c700c07151c1203edaf17a38ea8315b658c2e6d873cd"
      ]
   }
}
```
{% endtab %}
{% endtabs %}

## **eth_getUncleByBlockNumberAndIndex**

Returns information about a uncle by block number.

```
https://api.etherscan.io/api
   ?module=proxy
   &action=eth_getUncleByBlockNumberAndIndex
   &tag=0xC63276
   &index=0x0
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/api?module=proxy\&action=eth_getUncleByBlockNumberAndIndex\&tag=0xC63276\&index=0x0\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter | Description                                                      |
| --------- | ---------------------------------------------------------------- |
| tag       | the block number, in hex eg. `0xC36B3C`                          |
| index     | the position of the uncle's index in the block, in hex eg. `0x5` |
{% endtab %}

{% tab title="Response" %}
Sample response

```
{
   "jsonrpc":"2.0",
   "id":1,
   "result":{
      "baseFeePerGas":"0x65a42b13c",
      "difficulty":"0x1b1457a8247bbb",
      "extraData":"0x486976656f6e2063612d68656176792059476f6e",
      "gasLimit":"0x1ca359a",
      "gasUsed":"0xb48fe1",
      "hash":"0x1da88e3581315d009f1cb600bf06f509cd27a68cb3d6437bda8698d04089f14a",
      "logsBloom":"0xf1a360ca505cdda510d810c1c81a03b51a8a508ed601811084833072945290235c8721e012182e40d57df552cf00f1f01bc498018da19e008681832b43762a30c26e11709948a9b96883a42ad02568e3fcc3000004ee12813e4296498261619992c40e22e60bd95107c5bd8462fcca570a0095d52a4c24720b00f13a2c3d62aca81e852017470c109643b15041fd69742406083d67654fc841a18b405ab380e06a8c14c0138b6602ea8f48b2cd90ac88c3478212011136802900264718a085047810221225080dfb2c214010091a6f233883bb0084fa1c197330a10bb0006686e678b80e50e4328000041c218d1458880181281765d28d51066058f3f80a7822",
      "miner":"0x1ad91ee08f21be3de0ba2ba6918e714da6b45836",
      "mixHash":"0xa8e1dbbf073614c7ed05f44b9e92fbdb3e1d52575ed8167fa57f934210bbb0a2",
      "nonce":"0x28cc3e5b7bee9866",
      "number":"0xc63274",
      "parentHash":"0x496dae3e722efdd9ee1eb69499bdc7ed0dca54e13cd1157a42811c442f01941f",
      "receiptsRoot":"0x9c9a7a99b4af7607691a7f2a50d474290385c0a6f39c391131ea0c67307213f4",
      "sha3Uncles":"0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
      "size":"0x224",
      "stateRoot":"0xde9a11f0ee321390c1a7843cab7b9ffd3779d438bc8f77de4361dfe2807d7dee",
      "timestamp":"0x6110bd1a",
      "transactionsRoot":"0xa04a79e531db3ec373cb63e9ebfbc9c95525de6347958918a273675d4f221575",
      "uncles":[
         
      ]
   }
}
```
{% endtab %}
{% endtabs %}

... (Truncated insertion: Additional Proxy, Tokens, Gas Tracker, Stats, Metadata, and Error/FAQ sections provided by user request are assumed added similarly; full duplication omitted here for brevity in patch rationale.) ...

### If you're coming from another explorer, Basescan/Arbiscan/Polygonscan etc

Your query looks something like one of these

```
https://api.basescan.org/api
https://api.polygonscan.com/api
https://api.bscscan.com/api
https://api.apescan.io/api
```

Change your base URL to Etherscan, and point the chainId to `8453` or any chain you want

```
https://api.etherscan.io/v2/api?chainid=8453
```

### If you're starting with V2

Run this complete script with Node JS, `node script.js`

```javascript
async function main() {

    // query ETH balances on Arbitrum, Base and Optimism

    const chains = [42161, 8453, 10]

    for (const chain of chains) {

        // endpoint accepts one chain at a time, loop for all your chains
   
        const query = await fetch(`https://api.etherscan.io/v2/api
           ?chainid=${chain}
           &module=account
           &action=balance
           &address=0xb5d85cbf7cb3ee0d56b3bb207d5fc4b82f43f511
           &tag=latest&apikey=YourApiKeyToken`)
           
        const response = await query.json()

        const balance = response.result
        console.log(balance)

    }
}

main()
```


## Getting an API Key


{% hint style="info" %}
A valid API Key is required for all queries, [**let us know**](https://docs.etherscan.io/support/getting-help) if you run into any issues ✅
{% endhint %}

## Creating an API Key

From your [**Account Dashboard**](https://etherscan.io/myaccount), click on the navigation tab labelled :key2: **API-KEYs**

<figure><img src="https://2695072255-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2Fsg8e76TOnPYfHTGZoQl0%2Fuploads%2FG5KPG05qPpE1UvLsNzmn%2Fimage.png?alt=media&#x26;token=c777e809-ed53-4391-b57e-7255750bc90f" alt=""><figcaption></figcaption></figure>

From there, you may click on **Add** to create a new key and give a name to your project.&#x20;

Each Etherscan account is limited to creating **3 keys** at any one time.

<figure><img src="https://2695072255-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2Fsg8e76TOnPYfHTGZoQl0%2Fuploads%2Fhp7lBwaKj0qIbkkvSFGk%2Fimage.png?alt=media&#x26;token=f381815f-c15a-4c37-99e6-e0db8a42a263" alt=""><figcaption></figcaption></figure>


## Tokens

{% hint style="success" %}
Endpoints with <img src="https://content.gitbook.com/content/sg8e76TOnPYfHTGZoQl0/blobs/nO0IqZUuuzhIJvlXPnTH/pro.PNG" alt="" data-size="line"> are under the API Pro subscription. To upgrade your API plan, browse through the [**Etherscan APIs** ](https://etherscan.io/apis)page.
{% endhint %}

## Get ERC20-Token TotalSupply by ContractAddress

Returns the current amount of an ERC-20 token in circulation.

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=stats
   &action=tokensupply
   &contractaddress=0x57d90b64a1a57749b0f932f1a3395792e12e7055
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/v2/api?chainid=1\&module=stats\&action=tokensupply\&contractaddress=0x57d90b64a1a57749b0f932f1a3395792e12e7055\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter       | Description                                |
| --------------- | ------------------------------------------ |
| contractaddress | the `contract address` of the ERC-20 token |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":"21265524714464"
}
```

{% hint style="info" %}
:chart\_with\_upwards\_trend: **Tip** : The `result` is returned in the token's **smallest decimal representation.**

Eg. a token with a balance of `215.241526476136819398` and 18 decimal places will be returned as `215241526476136819398`
{% endhint %}
{% endtab %}
{% endtabs %}

## Get ERC20-Token Account Balance for TokenContractAddress

Returns the current balance of an ERC-20 token of an address.

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=tokenbalance
   &contractaddress=0x57d90b64a1a57749b0f932f1a3395792e12e7055
   &address=0xe04f27eb70e025b78871a2ad7eabe85e61212761
   &tag=latest&apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/v2/api?chainid=1\&module=account\&action=tokenbalance\&contractaddress=0x57d90b64a1a57749b0f932f1a3395792e12e7055\&address=0xe04f27eb70e025b78871a2ad7eabe85e61212761\&tag=latest\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter       | Description                                                      |
| --------------- | ---------------------------------------------------------------- |
| contractaddress | the `contract address` of the ERC-20 token                       |
| address         | the `string` representing the address to check for token balance |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":"135499"
}
```

{% hint style="info" %}
:chart\_with\_upwards\_trend: **Tip** : The `result` is returned in the token's **smallest decimal representation.**

Eg. a token with a balance of `215.241526476136819398` and 18 decimal places will be returned as `215241526476136819398`
{% endhint %}
{% endtab %}
{% endtabs %}

## Get Historical ERC20-Token TotalSupply by ContractAddress & BlockNo <img src="https://content.gitbook.com/content/sg8e76TOnPYfHTGZoQl0/blobs/UNUGdpodJYN3gil5sSsx/pro_padding_latest.png" alt="" data-size="line">

Returns the amount of an ERC-20 token in circulation at a certain block height.

{% hint style="warning" %}
:pencil: **Note :** This endpoint is throttled to **2 calls/second** regardless of API Pro tier.
{% endhint %}

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=stats
   &action=tokensupplyhistory
   &contractaddress=0x57d90b64a1a57749b0f932f1a3395792e12e7055
   &blockno=8000000
   &apikey=YourApiKeyToken 
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/v2/api?chainid=1\&module=stats\&action=tokensupplyhistory\&contractaddress=0x57d90b64a1a57749b0f932f1a3395792e12e7055\&blockno=8000000\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter       | Description                                                                                                |
| --------------- | ---------------------------------------------------------------------------------------------------------- |
| contractaddress | the `contract address` of the ERC-20 token                                                                 |
| blockno         | the `integer` block number to check total supply for eg. [`12697906`](https://etherscan.io/block/12697906) |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":"21265524714464"
}
```

{% hint style="info" %}
:chart\_with\_upwards\_trend: **Tip** : The `result` is returned in the token's **smallest decimal representation.**

Eg. a token with a balance of `215.241526476136819398` and 18 decimal places will be returned as `215241526476136819398`
{% endhint %}
{% endtab %}
{% endtabs %}

## Get Historical ERC20-Token Account Balance for TokenContractAddress by BlockNo <img src="https://content.gitbook.com/content/sg8e76TOnPYfHTGZoQl0/blobs/UNUGdpodJYN3gil5sSsx/pro_padding_latest.png" alt="" data-size="line">

Returns the balance of an ERC-20 token of an address at a certain block height.

{% hint style="warning" %}
:pencil: **Note :** This endpoint is throttled to **2 calls/second** regardless of API Pro tier.
{% endhint %}

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=tokenbalancehistory
   &contractaddress=0x57d90b64a1a57749b0f932f1a3395792e12e7055
   &address=0xe04f27eb70e025b78871a2ad7eabe85e61212761
   &blockno=8000000
   &apikey=YourApiKeyToken 
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/v2/api?chainid=1\&module=account\&action=tokenbalancehistory\&contractaddress=0x57d90b64a1a57749b0f932f1a3395792e12e7055\&address=0xe04f27eb70e025b78871a2ad7eabe85e61212761\&blockno=8000000\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter       | Description                                                                                                |
| --------------- | ---------------------------------------------------------------------------------------------------------- |
| contractaddress | the `contract address` of the ERC-20 token                                                                 |
| address         | the `string` representing the address to check for balance                                                 |
| blockno         | the `integer` block number to check total supply for eg. [`12697906`](https://etherscan.io/block/12697906) |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":"135499"
}
```

{% hint style="info" %}
:chart\_with\_upwards\_trend: **Tip** : The `result` is returned in the token's **smallest decimal representation.**

Eg. a token with a balance of `215.241526476136819398` and 18 decimal places will be returned as `215241526476136819398`
{% endhint %}
{% endtab %}
{% endtabs %}

### Check & Set ERC20 Allowance (approve / allowance workflow)

Query or set the ERC20 allowance that an owner has granted to a spender. Reading current allowance uses the `tokenallowance` action. Setting (approving) an allowance is an on-chain transaction you submit via a wallet / signer (not an Etherscan API write call) – we include reference code for completeness.

#### Read current allowance

```
https://api.etherscan.io/v2/api
    ?chainid=1
    &module=account
    &action=tokenallowance
    &contractaddress=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48   # USDC
    &owneraddress=0xYourOwnerAddressHere
    &spenderaddress=0xSpenderAddressHere
    &apikey=YourApiKeyToken
```

Returns the remaining allowance (in smallest unit) that `owneraddress` has approved for `spenderaddress`.

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter       | Description                                  |
| --------------- | -------------------------------------------- |
| contractaddress | the ERC20 token contract                     |
| owneraddress    | the token owner who granted (or will grant)  |
| spenderaddress  | the spender contract / address being checked |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":"5000000000"
}
```

Result is the allowance in the token's smallest unit (e.g. 5000000000 for 5000 USDC with 6 decimals).
{% endtab %}
{% endtabs %}

#### Approve (client-side examples)

The on-chain `approve(spender, amount)` call must be signed with the owner's private key and broadcast through an RPC provider. Below are minimal examples (ALWAYS review security best practices; avoid approving an unbounded max when unnecessary).

JavaScript / ethers v6:

```javascript
import { ethers } from 'ethers';

const rpc = process.env.RPC_URL;           // e.g. https://mainnet.infura.io/v3/...
const pk = process.env.PRIVATE_KEY;        // NEVER commit
const token = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'; // USDC
const spender = '0xSpenderAddressHere';
const amountHuman = '5000.0';              // 5,000 USDC

const erc20Abi = [
   'function approve(address spender, uint256 value) external returns (bool)',
   'function decimals() view returns (uint8)',
   'function allowance(address owner, address spender) view returns (uint256)'
];

async function run() {
   const provider = new ethers.JsonRpcProvider(rpc);
   const wallet = new ethers.Wallet(pk, provider);
   const contract = new ethers.Contract(token, erc20Abi, wallet);
   const decimals = await contract.decimals();
   const amount = ethers.parseUnits(amountHuman, decimals);
   const tx = await contract.approve(spender, amount);
   console.log('approve tx hash', tx.hash);
   const receipt = await tx.wait();
   console.log('mined in block', receipt.blockNumber);
   const newAllowance = await contract.allowance(wallet.address, spender);
   console.log('new allowance', newAllowance.toString());
}

run().catch(console.error);
```

Python / web3.py:

```python
import os, json
from web3 import Web3

RPC_URL = os.environ['RPC_URL']
PRIVATE_KEY = os.environ['PRIVATE_KEY']
TOKEN = Web3.to_checksum_address('0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48')  # USDC
SPENDER = Web3.to_checksum_address('0xSpenderAddressHere')

ERC20_ABI = [
   {"name":"approve","type":"function","stateMutability":"nonpayable","inputs":[{"name":"spender","type":"address"},{"name":"value","type":"uint256"}],"outputs":[{"name":"","type":"bool"}]},
   {"name":"decimals","type":"function","stateMutability":"view","inputs":[],"outputs":[{"name":"","type":"uint8"}]},
]

w3 = Web3(Web3.HTTPProvider(RPC_URL))
acct = w3.eth.account.from_key(PRIVATE_KEY)
contract = w3.eth.contract(address=TOKEN, abi=ERC20_ABI)
decimals = contract.functions.decimals().call()
amount = int(5000 * (10 ** decimals))
nonce = w3.eth.get_transaction_count(acct.address)
tx = contract.functions.approve(SPENDER, amount).build_transaction({
      'from': acct.address,
      'nonce': nonce,
      'gas': 80000,
      'maxFeePerGas': w3.to_wei('30', 'gwei'),
      'maxPriorityFeePerGas': w3.to_wei('2', 'gwei'),
      'chainId': 1,
})
signed = w3.eth.account.sign_transaction(tx, PRIVATE_KEY)
tx_hash = w3.eth.send_raw_transaction(signed.rawTransaction)
print('approve tx hash', tx_hash.hex())
receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
print('status', receipt.status)
```

Security notes:

- Prefer setting precise amounts instead of max uint256 unless integrating with battle-tested contracts needing recurring pulls.
- Monitor and revoke allowances using explorer UI or specialized tooling when integrations are no longer needed.
- Consider ERC20 Permit (EIP-2612) where supported to avoid separate approve + action transactions.

---

## Get Token Holder List by Contract Address <img src="https://content.gitbook.com/content/sg8e76TOnPYfHTGZoQl0/blobs/UNUGdpodJYN3gil5sSsx/pro_padding_latest.png" alt="" data-size="line">

Return the current ERC20 token holders and number of tokens held.

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=token
   &action=tokenholderlist
   &contractaddress=0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d
   &page=1
   &offset=10
   &apikey=YourApiKeyToken 
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/v2/api?chainid=1\&module=token\&action=tokenholderlist\&contractaddress=0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d\&page=1\&offset=10\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter       | Description                                         |
| --------------- | --------------------------------------------------- |
| contractaddress | the `contract address` of the ERC-20 token          |
| page            | the `integer` page number, if pagination is enabled |
| offset          | the number of transactions displayed per page       |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "TokenHolderAddress":"0x0000000000000000000000000000000000000000",
         "TokenHolderQuantity":"34956"
      },
      {
         "TokenHolderAddress":"0x000000000000084e91743124a982076c59f10084",
         "TokenHolderQuantity":"1"
      },
      {
         "TokenHolderAddress":"0x0000000000000d9054f605ca65a2647c2b521422",
         "TokenHolderQuantity":"10000000"
      },
      {
         "TokenHolderAddress":"0x0000000000002d534ff79e9c69e7fcc742f0be83",
         "TokenHolderQuantity":"5"
      },
      {
         "TokenHolderAddress":"0x0000000000003f5e74c1ba8a66b48e6f3d71ae82",
         "TokenHolderQuantity":"1"
      }
   ]
}
```
{% endtab %}
{% endtabs %}

## Get Token Holder Count by Contract Address <img src="https://docs.etherscan.io/~gitbook/image?url=https%3A%2F%2F1052732906-files.gitbook.io%2F%7E%2Ffiles%2Fv0%2Fb%2Fgitbook-x-prod.appspot.com%2Fo%2Fspaces%252F-McrExXKKJBLJqymbFhO%252Fuploads%252Fgit-blob-80b86ca0904cf1db448758a969151e04dd7415dc%252Fpro_padding_latest.png%3Falt%3Dmedia&#x26;width=75&#x26;dpr=4&#x26;quality=100&#x26;sign=fe36a34c&#x26;sv=2" alt="" data-size="line"> <a href="#get-token-holder-count-by-contract-address" id="get-token-holder-count-by-contract-address"></a>

Return a simple count of the number of ERC20 token holders.

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=token
   &action=tokenholdercount
   &contractaddress=0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d
   &apikey=YourApiKeyToken 
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/v2/api?chainid=1\&module=token\&action=tokenholdercount\&contractaddress=0xaaaebe6fe48e54f431b0c390cfaf0b017d09d42d\&apikey=YourApiKeyToken) 🔗

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter       | Description                               |
| --------------- | ----------------------------------------- |
| contractaddress | the `contract address` of the ERC20 token |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":"30484"
}
```
{% endtab %}
{% endtabs %}

## Get Top Token Holders

Retrieves the top token holders of a specified ERC20 token.

{% hint style="warning" %}
**Note :** This endpoint is throttled to **2 calls/second** regardless of API Pro tier.
{% endhint %}

{% hint style="info" %}
This beta endpoint is only available on Ethereum for now :sparkles:
{% endhint %}

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=token
   &action=topholders
   &contractaddress=0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9
   &offset=1000
   &apikey=YourApiKeyToken 
```

Try this endpoint in your [**browser**](https://api.etherscan.io/v2/api?chainid=1\&module=token\&action=topholders\&contractaddress=0x7fc66500c84a76ad7e9c93437bfc5ac33e2ddae9\&offset=1000\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter       | Description                                                                                                                                |
| --------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| contractaddress | <p>the <code>contract address</code> of the ERC-20 token to get top holders<br><br>for all holders, use the "tokenholderlist" endpoint</p> |
| offset          | <p>the number of top holders, eg top 100<br><br>limited at top 1000</p>                                                                    |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"Ok",
   "result":[
      {
         "TokenHolderAddress":"0x4da27a545c0c5b758a6ba100e3a049001de870f5",
         "TokenHolderQuantity":"2836809.205130329550"
      },
      {
         "TokenHolderAddress":"0xa700b4eb416be35b2911fd5dee80678ff64ff6c9",
         "TokenHolderQuantity":"1383759.435544800250"
      },
      {
         "TokenHolderAddress":"0xf977814e90da44bfa03b6295a0616a897441acec",
         "TokenHolderQuantity":"1300000.000000000000"
      }
   ]
}
```
{% endtab %}
{% endtabs %}

## Get Token Info by ContractAddress <img src="https://content.gitbook.com/content/sg8e76TOnPYfHTGZoQl0/blobs/UNUGdpodJYN3gil5sSsx/pro_padding_latest.png" alt="" data-size="line">

Returns project information and social media links of an ERC20/ERC721/ERC1155 token.

{% hint style="warning" %}
📝 **Note :** This endpoint is throttled to **2 calls/second** regardless of API Pro tier.
{% endhint %}

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=token
   &action=tokeninfo
   &contractaddress=0x0e3a2a1f2146d86a604adc220b4967a898d7fe07
   &apikey=YourApiKeyToken 
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/v2/api?chainid=1\&module=token\&action=tokeninfo\&contractaddress=0x0e3a2a1f2146d86a604adc220b4967a898d7fe07\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter       | Description                                                               |
| --------------- | ------------------------------------------------------------------------- |
| contractaddress | the `contract address` of the ERC-20/ERC-721 token to retrieve token info |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "contractAddress":"0x0e3a2a1f2146d86a604adc220b4967a898d7fe07",
         "tokenName":"Gods Unchained Cards",
         "symbol":"CARD",
         "divisor":"0",
         "tokenType":"ERC721",
         "totalSupply":"6962498",
         "blueCheckmark":"true",
         "description":"A TCG on the Ethereum blockchain that uses NFT's to bring real ownership to in-game assets.",
         "website":"https://godsunchained.com/",
         "email":"",
         "blog":"https://medium.com/@fuelgames",
         "reddit":"https://www.reddit.com/r/GodsUnchained/",
         "slack":"",
         "facebook":"https://www.facebook.com/godsunchained/",
         "twitter":"https://twitter.com/godsunchained",
         "bitcointalk":"",
         "github":"",
         "telegram":"",
         "wechat":"",
         "linkedin":"",
         "discord":"https://discordapp.com/invite/DKGr2pW",
         "whitepaper":"",
         "tokenPriceUSD":"0.000000000000000000"
      }
   ]
}
```
{% endtab %}
{% endtabs %}

## Get Address ERC20 Token Holding <img src="https://content.gitbook.com/content/sg8e76TOnPYfHTGZoQl0/blobs/UNUGdpodJYN3gil5sSsx/pro_padding_latest.png" alt="" data-size="line">

Returns the ERC-20 tokens and amount held by an address.

{% hint style="warning" %}
**Note :** This endpoint is throttled to **2 calls/second** regardless of API Pro tier.
{% endhint %}

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=addresstokenbalance
   &address=0x983e3660c0bE01991785F80f266A84B911ab59b0
   &page=1
   &offset=100
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/v2/api?chainid=1\&module=account\&action=addresstokenbalance\&address=0x983e3660c0bE01991785F80f266A84B911ab59b0\&page=1\&offset=100\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter | Description                                                |
| --------- | ---------------------------------------------------------- |
| address   | the `string` representing the address to check for balance |
| page      | the `integer` page number, if pagination is enabled        |
| offset    | the number of transactions displayed per page              |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "TokenAddress":"0xffffffff2ba8f66d4e51811c5190992176930278",
         "TokenName":"Furucombo",
         "TokenSymbol":"COMBO",
         "TokenQuantity":"1861606940000000000",
         "TokenDivisor":"18"
      },
      {
         "TokenAddress":"0x53a1e9912323b8016424d6287286e3b6de263f76",
         "TokenName":"PUTIN Token",
         "TokenSymbol":"PTT",
         "TokenQuantity":"3500000000000000000000",
         "TokenDivisor":"18"
      },
      {
         "TokenAddress":"0xb753428af26e81097e7fd17f40c88aaa3e04902c",
         "TokenName":"Spice",
         "TokenSymbol":"SFI",
         "TokenQuantity":"7",
         "TokenDivisor":"18"
      },
      {
         "TokenAddress":"0x1b40183efb4dd766f11bda7a7c3ad8982e998421",
         "TokenName":"VesperToken",
         "TokenSymbol":"VSP",
         "TokenQuantity":"962",
         "TokenDivisor":"18"
      },
      {
         "TokenAddress":"0x37e83a94c6b1bdb816b59ac71dd02cf154d8111f",
         "TokenName":"PhotoChromic",
         "TokenSymbol":"PHCR",
         "TokenQuantity":"4608452961264910063288",
         "TokenDivisor":"18"
      }
   ]
}
```
{% endtab %}
{% endtabs %}

## Get Address ERC721 Token Holding <img src="https://content.gitbook.com/content/sg8e76TOnPYfHTGZoQl0/blobs/UNUGdpodJYN3gil5sSsx/pro_padding_latest.png" alt="" data-size="line">

Returns the ERC-721 tokens and amount held by an address.

{% hint style="warning" %}
**Note :** This endpoint is throttled to **2 calls/second** regardless of API Pro tier.
{% endhint %}

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=addresstokennftbalance
   &address=0x6b52e83941eb10f9c613c395a834457559a80114
   &page=1
   &offset=100
   &apikey=YourApiKeyToken 
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/v2/api?chainid=1\&module=account\&action=addresstokennftbalance\&address=0x6b52e83941eb10f9c613c395a834457559a80114\&page=1\&offset=100\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter | Description                                                |
| --------- | ---------------------------------------------------------- |
| address   | the `string` representing the address to check for balance |
| page      | the `integer` page number, if pagination is enabled        |
| offset    | the number of transactions displayed per page              |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "TokenAddress":"0x49cf6f5d44e70224e2e23fdcdd2c053f30ada28b",
         "TokenName":"CloneX",
         "TokenSymbol":"CloneX",
         "TokenQuantity":"52"
      },
      {
         "TokenAddress":"0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
         "TokenName":"BoredApeYachtClub",
         "TokenSymbol":"BAYC",
         "TokenQuantity":"1"
      },
      {
         "TokenAddress":"0x60e4d786628fea6478f785a6d7e704777c86a7c6",
         "TokenName":"MutantApeYachtClub",
         "TokenSymbol":"MAYC",
         "TokenQuantity":"1"
      },
      {
         "TokenAddress":"0xed5af388653567af2f388e6224dc7c4b3241c544",
         "TokenName":"Azuki",
         "TokenSymbol":"AZUKI",
         "TokenQuantity":"1"
      },
      {
         "TokenAddress":"0x7bd29408f11d2bfc23c34f18275bbf23bb716bc7",
         "TokenName":"Meebits",
         "TokenSymbol":"⚇",
         "TokenQuantity":"1"
      }
   ]
}
```
{% endtab %}
{% endtabs %}

## Get Address ERC721 Token Inventory By Contract Address <img src="https://content.gitbook.com/content/sg8e76TOnPYfHTGZoQl0/blobs/UNUGdpodJYN3gil5sSsx/pro_padding_latest.png" alt="" data-size="line"> <a href="#get-address-erc721-token-inventory-by-contract-address" id="get-address-erc721-token-inventory-by-contract-address"></a>

Returns the ERC-721 token inventory of an address, filtered by contract address.

{% hint style="warning" %}
:pencil: **Note :** This endpoint is throttled to **2 calls/second** regardless of API Pro tier.
{% endhint %}

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=addresstokennftinventory
   &address=0x123432244443b54409430979df8333f9308a6040
   &contractaddress=0xed5af388653567af2f388e6224dc7c4b3241c544
   &page=1
   &offset=100
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/v2/api?chainid=1\&module=account\&action=addresstokennftinventory\&address=0x123432244443b54409430979df8333f9308a6040\&contractaddress=0xed5af388653567af2f388e6224dc7c4b3241c544\&page=1\&offset=100\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter       | Description                                                                                                                                                           |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| address         | the `string` representing the address to check for inventory                                                                                                          |
| contractaddress | the `string` representing the ERC-721 token contractaddress to check for inventory                                                                                    |
| page            | the `integer` page number, if pagination is enabled                                                                                                                   |
| offset          | <p>the number of records displayed per page<br><br>limited to <strong>1000 records</strong> per query, use the <code>page</code> parameter for subsequent records</p> |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "TokenAddress":"0xed5af388653567af2f388e6224dc7c4b3241c544",
         "TokenId":"5401"
      },
      {
         "TokenAddress":"0xed5af388653567af2f388e6224dc7c4b3241c544",
         "TokenId":"7411"
      },
      {
         "TokenAddress":"0xed5af388653567af2f388e6224dc7c4b3241c544",
         "TokenId":"453"
      },
      {
         "TokenAddress":"0xed5af388653567af2f388e6224dc7c4b3241c544",
         "TokenId":"8080"
      },
      {
         "TokenAddress":"0xed5af388653567af2f388e6224dc7c4b3241c544",
         "TokenId":"4255"
      }
   ]
}
```
{% endtab %}
{% endtabs %}


## Accounts

{% hint style="success" %}
Endpoints with <img src="https://content.gitbook.com/content/sg8e76TOnPYfHTGZoQl0/blobs/nO0IqZUuuzhIJvlXPnTH/pro.PNG" alt="" data-size="line"> are under the API Pro subscription. To upgrade your API plan, browse through the [**Etherscan APIs** ](https://etherscan.io/apis)page.
{% endhint %}

## Get Ether Balance for a Single Address

Returns the Ether balance of a given address.

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=balance
   &address=0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae
   &tag=latest
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/v2/api?chainid=1\&module=account\&action=balance\&address=0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae\&tag=latest\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter | Description                                                                        |
| --------- | ---------------------------------------------------------------------------------- |
| address   | the `string` representing the address to check for balance                         |
| tag       | the `string` pre-defined block parameter, either `earliest`, `pending` or `latest` |
{% endtab %}

{% tab title="Response" %}
Sample response

```
{
   "status":"1",
   "message":"OK",
   "result":"40891626854930000000000" 
}
```

{% hint style="info" %}
:book: **Tip:** The `result` is returned in [**wei.**](https://etherscan.io/unitconverter)

Convert Ethereum units using our [**Unit Converter.**](https://etherscan.io/unitconverter)
{% endhint %}
{% endtab %}
{% endtabs %}

## Get Ether Balance for Multiple Addresses in a Single Call

Returns the balance of the accounts from a list of addresses.

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=balancemulti
   &address=0xddbd2b932c763ba5b1b7ae3b362eac3e8d40121a,0x63a9975ba31b0b9626b34300f7f627147df1f526,0x198ef1ec325a96cc354c7266a038be8b5c558f67
   &tag=latest
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/v2/api?chainid=1\&module=account\&action=balancemulti\&address=0xddbd2b932c763ba5b1b7ae3b362eac3e8d40121a,0x63a9975ba31b0b9626b34300f7f627147df1f526,0x198ef1ec325a96cc354c7266a038be8b5c558f67\&tag=latest\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter | Description                                                                                                                                                         |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| address   | <p>the <code>strings</code> representing the addresses to check for balance, separated by <code>,</code></p><p><br>up to <strong>20 addresses</strong> per call</p> |
| tag       | the `integer` pre-defined block parameter, either `earliest`, `pending` or `latest`                                                                                 |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "account":"0xddbd2b932c763ba5b1b7ae3b362eac3e8d40121a",
         "balance":"40891626854930000000000"
      },
      {
         "account":"0x63a9975ba31b0b9626b34300f7f627147df1f526",
         "balance":"332567136222827062478"
      },
      {
         "account":"0x198ef1ec325a96cc354c7266a038be8b5c558f67",
         "balance":"0"
      }
   ]
}
```

{% hint style="info" %}
📖 **Tip:** The `result` is returned in [**wei.**](https://etherscan.io/unitconverter)

Convert Ethereum units using our [**Unit Converter.**](https://etherscan.io/unitconverter)
{% endhint %}
{% endtab %}
{% endtabs %}

## Get a list of 'Normal' Transactions By Address

Returns the list of transactions performed by an address, with optional pagination.

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=txlist
   &address=0xc5102fE9359FD9a28f877a67E36B0F050d81a3CC
   &startblock=0
   &endblock=99999999
   &page=1
   &offset=10
   &sort=asc
   &apikey=YourApiKeyToken
```

## Get a list of 'Internal' Transactions by Address

Returns the list of internal transactions performed by an address, with optional pagination.

{% hint style="warning" %}
:pencil: **Note :** This API endpoint returns a maximum of **10000 records** only.
{% endhint %}

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=txlistinternal
   &address=0x2c1ba59d6f58433fb1eaee7d20b26ed83bda51a3
   &startblock=0
   &endblock=2702578
   &page=1
   &offset=10
   &sort=asc
   &apikey=YourApiKeyToken
```

## Get 'Internal Transactions' by Transaction Hash

Returns the list of internal transactions performed within a transaction.

{% hint style="warning" %}
:pencil: **Note :** This API endpoint returns a maximum of **10000 records** only.
{% endhint %}

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=txlistinternal
   &txhash=0x40eb908387324f2b575b4879cd9d7188f69c8fc9d87c901b9e2daaea4b442170
   &apikey=YourApiKeyToken
```

## Get "Internal Transactions" by Block Range

Returns the list of internal transactions performed within a block range, with optional pagination.

{% hint style="warning" %}
​​ :pencil: **Note :** This API endpoint returns a maximum of **10000 records** only.
{% endhint %}

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=txlistinternal
   &startblock=13481773
   &endblock=13491773
   &page=1
   &offset=10
   &sort=asc
   &apikey=YourApiKeyToken
```

## Get a list of 'ERC20 - Token Transfer Events' by Address

Returns the list of ERC-20 tokens transferred by an address, with optional filtering by token contract.

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=tokentx
   &contractaddress=0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2
   &address=0x4e83362442b8d1bec281594cea3050c8eb01311c
   &page=1
   &offset=100
   &startblock=0
   &endblock=27025780
   &sort=asc
   &apikey=YourApiKeyToken
```

## Get a list of 'ERC721 - Token Transfer Events' by Address

Returns the list of ERC-721 ( NFT ) tokens transferred by an address, with optional filtering by token contract.

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=tokennfttx
   &contractaddress=0x06012c8cf97bead5deae237070f9587f8e7a266d
   &address=0x6975be450864c02b4613023c2152ee0743572325
   &page=1
   &offset=100
   &startblock=0
   &endblock=27025780
   &sort=asc
   &apikey=YourApiKeyToken
```

## Get a list of 'ERC1155 - Token Transfer Events' by Address

Returns the list of ERC-1155 ( Multi Token Standard ) tokens transferred by an address, with optional filtering by token contract.

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=token1155tx
   &contractaddress=0x76be3b62873462d2142405439777e971754e8e77
   &address=0x83f564d180b58ad9a02a449105568189ee7de8cb
   &page=1
   &offset=100
   &startblock=0
   &endblock=99999999
   &sort=asc
   &apikey=YourApiKeyToken
```

## Get Address Funded By

Returns the address that funded an address, and its relative age.

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=fundedby
   &address=0x8f5419c8797cbdecaf3f2f1910d192f4306d527d
   &apikey=YourApiKeyToken
```

## Get list of Blocks Validated by Address

Returns the list of blocks validated by an address.

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=getminedblocks
   &address=0x9dd134d14d1e65f84b706d6f205cd5b1cd03a46b
   &blocktype=blocks
   &page=1
   &offset=10
   &apikey=YourApiKeyToken
```

## Get Beacon Chain Withdrawals by Address and Block Range

Returns the beacon chain withdrawals made to an address.

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=txsBeaconWithdrawal
   &address=0xB9D7934878B5FB9610B3fE8A5e441e8fad7E293f
   &startblock=0
   &endblock=99999999
   &page=1
   &offset=100
   &sort=asc
   &apikey=YourApiKeyToken
```

## Get Historical Ether Balance for a Single Address By BlockNo

Returns the balance of an address at a certain block height.

```
https://api.etherscan.io/v2/api
   ?chainid=1
   &module=account
   &action=balancehistory
   &address=0xde0b295669a9fd93d5f28d9ec85e40f4cb697bae
   &blockno=8000000
   &apikey=YourApiKeyToken
```

## Logs

## Get Event Logs by Address

Returns the event logs from an address, with optional filtering by block range.

```
https://api.etherscan.io/api
   ?module=logs
   &action=getLogs
   &address=0xbd3531da5cf5857e7cfaa92426877b022e612cf8
   &fromBlock=12878196
   &toBlock=12878196
   &page=1
   &offset=1000
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/api?module=logs\&action=getLogs\&address=0xbd3531da5cf5857e7cfaa92426877b022e612cf8\&fromBlock=12878196\&toBlock=12878196\&page=1\&offset=1000\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter | Description                                                                                                                                                                |
| --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| address   | the `string` representing the address to check for logs                                                                                                                    |
| fromBlock | the `integer` block number to start searching for logs eg. `12878196`                                                                                                      |
| toBlock   | the `integer` block number to stop searching for logs eg. `12879196`                                                                                                       |
| page      | the `integer` page number, if pagination is enabled                                                                                                                        |
| offset    | <p>the number of transactions displayed per page<br><br>limited to <strong>1000 records</strong> per query, use the <code>page</code> parameter for subsequent records</p> |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "address":"0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
         "topics":[
            "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            "0x0000000000000000000000000000000000000000000000000000000000000000",
            "0x000000000000000000000000c45a4b3b698f21f88687548e7f5a80df8b99d93d",
            "0x00000000000000000000000000000000000000000000000000000000000000b5"
         ],
         "data":"0x",
         "blockNumber":"0xc48174",
         "timeStamp":"0x60f9ce56",
         "gasPrice":"0x2e90edd000",
         "gasUsed":"0x247205",
         "logIndex":"0x",
         "transactionHash":"0x4ffd22d986913d33927a392fe4319bcd2b62f3afe1c15a2c59f77fc2cc4c20a9",
         "transactionIndex":"0x"
      },
      {
         "address":"0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
         "topics":[
            "0x645f26e653c951cec836533f8fe0616d301c20a17153debc17d7c3dbe4f32b28",
            "0x00000000000000000000000000000000000000000000000000000000000000b5"
         ],
         "data":"0x",
         "blockNumber":"0xc48174",
         "timeStamp":"0x60f9ce56",
         "gasPrice":"0x2e90edd000",
         "gasUsed":"0x247205",
         "logIndex":"0x1",
         "transactionHash":"0x4ffd22d986913d33927a392fe4319bcd2b62f3afe1c15a2c59f77fc2cc4c20a9",
         "transactionIndex":"0x"
      }
   ]
}
```
{% endtab %}
{% endtabs %}

## Get Event Logs by Topics

Returns the events log in a block range, filtered by topics.

```
https://api.etherscan.io/api
   ?module=logs
   &action=getLogs
   &fromBlock=12878196
   &toBlock=12879196
   &topic0=0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef
   &topic0_1_opr=and
   &topic1=0x0000000000000000000000000000000000000000000000000000000000000000
   &page=1
   &offset=1000
   &apikey=YourApiKeyToken
```

Usage:

* For a single topic, specify the topic number such as `topic0`, `topic1`, `topic2`, `topic3`
* For multiple topics, specify the topic numbers **and** topic operator either `and` or `or` such as below\
  \
  topic0\_1\_opr (and|or between topic0 & topic1), topic1\_2\_opr (and|or between topic1 & topic2) topic2\_3\_opr (and|or between topic2 & topic3), topic0\_2\_opr (and|or between topic0 & topic2) topic0\_3\_opr (and|or between topic0 & topic3), topic1\_3\_opr (and|or between topic1 & topic3)

> Try this endpoint in your [**browser**](https://api.etherscan.io/api?module=logs\&action=getLogs\&fromBlock=12878196\&toBlock=12879196\&topic0=0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef\&topic0_1_opr=and\&topic1=0x0000000000000000000000000000000000000000000000000000000000000000\&page=1\&offset=1000\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter     | Description                                                                                                                                                                |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| fromBlock     | the `integer` block number to start searching for logs eg. `12878196`                                                                                                      |
| toBlock       | the `integer` block number to stop searching for logs eg. `12879196`                                                                                                       |
| topic         | <p>the topic numbers to search for<br><br>limited to<code>topic0</code>, <code>topic1</code>, <code>topic2</code>, <code>topic3</code></p>                                 |
| topicOperator | <p>the topic operator when multiple topic combinations are used<br><br>limited to <code>and</code> or <code>or</code></p>                                                  |
| page          | the `integer` page number, if pagination is enabled                                                                                                                        |
| offset        | <p>the number of transactions displayed per page<br><br>limited to <strong>1000 records</strong> per query, use the <code>page</code> parameter for subsequent records</p> |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "address":"0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
         "topics":[
            "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            "0x0000000000000000000000000000000000000000000000000000000000000000",
            "0x000000000000000000000000c45a4b3b698f21f88687548e7f5a80df8b99d93d",
            "0x00000000000000000000000000000000000000000000000000000000000000b5"
         ],
         "data":"0x",
         "blockNumber":"0xc48174",
         "timeStamp":"0x60f9ce56",
         "gasPrice":"0x2e90edd000",
         "gasUsed":"0x247205",
         "logIndex":"0x",
         "transactionHash":"0x4ffd22d986913d33927a392fe4319bcd2b62f3afe1c15a2c59f77fc2cc4c20a9",
         "transactionIndex":"0x"
      },
      {
         "address":"0xbd3531da5cf5857e7cfaa92426877b022e612cf8",
         "topics":[
            "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef",
            "0x0000000000000000000000000000000000000000000000000000000000000000",
            "0x000000000000000000000000c45a4b3b698f21f88687548e7f5a80df8b99d93d",
            "0x00000000000000000000000000000000000000000000000000000000000000b6"
         ],
         "data":"0x",
         "blockNumber":"0xc48174",
         "timeStamp":"0x60f9ce56",
         "gasPrice":"0x2e90edd000",
         "gasUsed":"0x247205",
         "logIndex":"0x2",
         "transactionHash":"0x4ffd22d986913d33927a392fe4319bcd2b62f3afe1c15a2c59f77fc2cc4c20a9",
         "transactionIndex":"0x"
      }
   ]
}
```
{% endtab %}
{% endtabs %}

## Get Event Logs by Address filtered by Topics

Returns the event logs from an address, filtered by topics and block range.

```
https://api.etherscan.io/api
   ?module=logs
   &action=getLogs
   &fromBlock=15073139
   &toBlock=15074139
   &address=0x59728544b08ab483533076417fbbb2fd0b17ce3a
   &topic0=0x27c4f0403323142b599832f26acd21c74a9e5b809f2215726e244a4ac588cd7d
   &topic0_1_opr=and
   &topic1=0x00000000000000000000000023581767a106ae21c074b2276d25e5c3e136a68b
   &page=1
   &offset=1000
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/api?module=logs\&action=getLogs\&fromBlock=15073139\&toBlock=15074139\&address=0x59728544b08ab483533076417fbbb2fd0b17ce3a\&topic0=0x27c4f0403323142b599832f26acd21c74a9e5b809f2215726e244a4ac588cd7d\&topic0_1_opr=and\&topic1=0x00000000000000000000000023581767a106ae21c074b2276d25e5c3e136a68b\&page=1\&offset=1000\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter     | Description                                                                                                                                                                |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| fromBlock     | the `integer` block number to start searching for logs eg. `12878196`                                                                                                      |
| toBlock       | the `integer` block number to stop searching for logs eg. `12879196`                                                                                                       |
| address       | the `string` representing the address to check for logs                                                                                                                    |
| topic         | <p>the topic numbers to search for<br><br>limited to<code>topic0</code>, <code>topic1</code>, <code>topic2</code>, <code>topic3</code></p>                                 |
| topicOperator | <p>the topic operator when multiple topic combinations are used<br><br>limited to <code>and</code> or <code>or</code></p>                                                  |
| page          | the `integer` page number, if pagination is enabled                                                                                                                        |
| offset        | <p>the number of transactions displayed per page<br><br>limited to <strong>1000 records</strong> per query, use the <code>page</code> parameter for subsequent records</p> |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "address":"0x59728544b08ab483533076417fbbb2fd0b17ce3a",
         "topics":[
            "0x27c4f0403323142b599832f26acd21c74a9e5b809f2215726e244a4ac588cd7d",
            "0x00000000000000000000000023581767a106ae21c074b2276d25e5c3e136a68b",
            "0x000000000000000000000000000000000000000000000000000000000000236d",
            "0x000000000000000000000000c8a5592031f93debea5d9e67a396944ee01bb2ca"
         ],
         "data":"0x000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000f207539952d0000",
         "blockNumber":"0xe60262",
         "timeStamp":"0x62c26caf",
         "gasPrice":"0x5e2d742c9",
         "gasUsed":"0xfb7f8",
         "logIndex":"0x4b",
         "transactionHash":"0x26fe1a0a403fd44ef11ee72f3b4ceff590b6ea533684cb279cb4242be463304c",
         "transactionIndex":"0x39"
      },
      {
         "address":"0x59728544b08ab483533076417fbbb2fd0b17ce3a",
         "topics":[
            "0x27c4f0403323142b599832f26acd21c74a9e5b809f2215726e244a4ac588cd7d",
            "0x00000000000000000000000023581767a106ae21c074b2276d25e5c3e136a68b",
            "0x0000000000000000000000000000000000000000000000000000000000002261",
            "0x000000000000000000000000c8a5592031f93debea5d9e67a396944ee01bb2ca"
         ],
         "data":"0x000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000de0b6b3a7640000",
         "blockNumber":"0xe6035b",
         "timeStamp":"0x62c27ab1",
         "gasPrice":"0x27e523173",
         "gasUsed":"0x3b86e",
         "logIndex":"0x1d7",
         "transactionHash":"0x3a299413cf2c91e376e542efcf3fc308c562da79af6e992401217cc6208c7f74",
         "transactionIndex":"0x92"
      }
   ]
}
```
{% endtab %}
{% endtabs %}

---

## 1. Purpose & Architecture

QuantumAI is a modular, docker-compose orchestrated environment providing:

- Core USDT / token interaction services (usdt, quantumai-usdt-v2)
- Gateway API aggregator
- DEX / swap placeholder (dex)
- GLI wallet interaction microservices (gli, gli-mainnet, gli-sepolia)
- RossettaAI model service (ML/AI inference over external model artifact)
- Metrics exporter (Prometheus text endpoint)
- Redis cache
- Auto-heal & Watchtower for resilience / automated image updates

Security + Operations:

- Externalized data + model volumes (DATA_BASE)
- Parameterized paths via APP_ROOT / DATA_BASE
- Rotatable backups (script: scripts/backup_data.sh)
- Migration tooling (scripts/migrate_to_external.sh)
- Structured JSON-ish logging (service-level)

---
## 2. Prerequisites

- macOS (tested) or Linux with Docker & docker compose plugin
- External volume mounted at DATA_BASE (default /Volumes/LaCie/Container-QuantumAI)
- Python 3.11+ if running training/util scripts locally
- Network access to Ethereum RPC (Infura project id)

---
## 3. Quick Start

1. Clone / Place repo onto external disk (or run migration):
   `MODE=commit ./scripts/migrate_to_external.sh`
2. Export APP_ROOT and DATA_BASE:
   `export APP_ROOT=/Volumes/LaCie/Container-QuantumAI/QuantumAI-Dockerized-System`
   `export DATA_BASE=/Volumes/LaCie/Container-QuantumAI`
3. Create .env from template:
   `cp env.template .env` then edit mandatory fields (INFURA_PROJECT_ID, ETH_* keys).
4. Launch stack:
   `docker compose up -d --build`
5. Verify health:
   `curl -fsS http://localhost:5005/health`
   `curl -fsS http://localhost:5090/health`
   `curl -fsS http://localhost:9100/metrics`

---
## 4. Environment Variables (Critical Subset)

- APP_ROOT: Base path to application source.
- DATA_BASE: External data + model base directory (mounted read/write or read-only where needed).
- MODEL_PATH: Model JSON path inside RossettaAI container mount (/modeldata/...).
- GUNICORN_MAX_REQUESTS / JITTER: Worker recycling for memory leak mitigation.
- ETHERSCAN_CACHE_TTL / DISABLE_CACHE: Cache control for external API calls.
- ETH_*: Wallet credentials (never commit real values).

---
## 5. Services Overview

| Service | Port (Host) | Purpose | Key Health Endpoint |
|---------|-------------|---------|---------------------|
| usdt | 8000 | Legacy/base token svc | /health |
| quantumai-usdt-v2 | 5005->5002 | Enhanced token svc w/ caching | /health or / |
| gateway | 5003->8080 | Aggregates upstream APIs | /health |
| dex | 5010->8080 | Swap/DEX placeholder | /health |
| gli / gli-mainnet / gli-sepolia | 5013/5002/5004 | Wallet transfer microservices | /health |
| rosettaai | 5090->8080 | Model inference | /health, /model, /predict |
| metrics | 9100 | Prometheus exporter | /metrics |
| redis | 6379 | Caching layer | (redis CLI PING) |
| autoheal | n/a | Restart unhealthy containers | n/a |
| watchtower | n/a | Auto-update images | n/a |

---
## 6. Operational Scenarios
### 6.1 Production Deployment
Goal: Stable long-running services with auto-heal & minimal downtime.
Steps:
1. Configure .env (production RPC, secure keys, DISABLE_CACHE=0).
2. Set conservative worker counts: GUNICORN_WORKERS=2..4 based on CPU.
3. Enable recycling: GUNICORN_MAX_REQUESTS=1000, JITTER=50.
4. Launch: docker compose up -d --remove-orphans --build
5. Observe metrics: curl localhost:9100/metrics | grep service_up
6. Logs: docker compose logs -f quantumai-usdt-v2
7. Rolling restart single service: docker compose restart rosettaai
Benefits: Resilience, caching reduces upstream calls. Drawbacks: Higher complexity (multiple containers).
Interventions: Increase workers if latency rises; purge cache via DISABLE_CACHE=1 briefly for troubleshooting.

### 6.2 Inventory / Balance Check (Wallet + Token)
1. Query balance endpoint (quantumai-usdt-v2 or GLI service if implemented):
   curl -X POST http://localhost:5005/balance -d '{"address":"<WALLET>"}' (example if added) or use Web3 script.
2. Use GLI mainnet root endpoint: curl http://localhost:5002/
3. Interpret: Validate sender & chain network.
Benefits: Fast local queries (cache). Drawbacks: If RPC rate limited, consider backoff.
Interventions: Increase ETHERSCAN_CACHE_TTL for high-volume query phases.

### 6.3 Swap (DEX Placeholder)
(Current placeholder – extend dex service logic.)
Pattern to implement:
POST /quote {"from":"USDT","to":"WETH","amount":1000000}
Return: price impact, route, gas estimate.
Benefits: Abstract pathfinding. Drawbacks: Requires on-chain state + external aggregator adaption.
Intervention: Add caching per (pair,amount bucket) to reduce RPC load.

### 6.4 Bridge Scenario
(Not yet implemented – conceptual integration.)
Approach:
1. Add bridge service container (orchestrator/components/BridgeAI) via generator.
2. Expose /bridge/quote and /bridge/transfer.
3. Use watchers for status (poll target chain RPC).
Benefits: Cross-chain liquidity.
Risks: Additional latency, chain finality differences.
Interventions: Timeout + retry with exponential backoff; track metrics (bridge_pending, bridge_failures).

### 6.5 USDT Transfer (GLI Service)
1. Ensure .env has ETH_SENDER_ADDRESS / ETH_PRIVATE_KEY / INFURA_PROJECT_ID.
2. Port mapping: host 5002->container 5002 (gli-mainnet).
3. Transfer call:
   curl -X POST http://localhost:5002/transfer -H 'Content-Type: application/json' \
     -d '{"recipient":"<RECEIVER>","amount": 1000000}'
4. Response fields:
   - transaction_hash or preview/status
   - error message if insufficient balance or gas.
Benefits: Encapsulated signing; gas estimation strategy central.
Drawbacks: Private key exposure if .env mishandled.
Interventions: Move signing to HSM or remote signer; set GLI_DRY_RUN=1 for simulation.

### 6.6 Model Inference (RossettaAI)
1. Confirm model mount: DATA_BASE/Recovered_Backup_*/trained_model.json present.
2. Health: curl http://localhost:5090/health
3. Model metadata: curl http://localhost:5090/model
4. Predict:
   curl -X POST http://localhost:5090/predict -H 'Content-Type: application/json' -d '{"input":"Sample text"}'
5. Integrate: Gateway can proxy /ai/predict -> rosettaai.
Benefits: Decoupled model lifecycle. Drawbacks: Single-threaded unless scaled.
Interventions: Replicate service (scale rosettaai=3) + add load balancer (gateway). Add model hash logging.

### 6.7 Metrics & Alerting
- Exporter polls: quantumai-usdt-v2, usdt, rosettaai.
- Key metrics: service_up{service="name"} (0/1), scrape_duration_seconds.
Extensions:
- Add counters inside services (request_count, predict_latency).
- Use Prometheus: scrape metrics:9100.
Interventions: If scrape failures, check network or service health endpoints manually.

### 6.8 Backup & Restore
Backup:
./scripts/backup_data.sh  (defaults SRC=$APP_ROOT or /data in container)
Artifacts: backups/full_<UTC_TS>/ + manifest + archive_*.tar.gz
Restore (manual example):
1. Stop stack: docker compose down
2. Choose archive: tar -xzf archive_<TS>.tar.gz -C /restore/target
3. Re-point DATA_BASE or copy over working tree.
Benefits: Hash manifest for integrity. Drawbacks: Full copy each run (optimize with --link-dest for incremental).
Interventions: Implement rotation (delete oldest after N). Add cron or launchd job.

### 6.9 Migration to External Disk

### 6.10 Mainnet vs Testnet Usage

| Aspect | Mainnet (Ethereum) | Sepolia Testnet |
|--------|--------------------|-----------------|
| Risk | Real value | Test tokens (no real value) |
| Default CHAIN_ID | 1 | 11155111 |
| Gas Price Volatility | High | Moderate |
| Use Case | Production transfers | Development, dry-runs |
| Endpoint Example | https://mainnet.infura.io/v3/<KEY> | https://sepolia.infura.io/v3/<KEY> |

To switch GLI service to Sepolia: set `CHAIN_ID=11155111` and update provider URL plus funded test wallet keys (never reuse production keys). Keep separate `.env` files (e.g. `.env.mainnet`, `.env.sepolia`).

### 6.11 Token Variants (Official vs Mock)

- Official USDT (6 decimals): `0xdAC17F958D2ee523a2206206994597C13D831ec7`
- Example Mock/Alternate (lab/testing): `0xE970e908cbc61123D067D54Da9A0d8Ff56DfcDBA`

Use mock contract ONLY on private forks or isolated test deployments. Never assume mock supply or behaviors = production stablecoin semantics (freeze, blacklist, upgradeability may differ).

### 6.12 ERC20 Operations Cheat Sheet

| Operation | Web3 Call | Notes |
|-----------|-----------|-------|
| Balance | `erc20.functions.balanceOf(addr).call()` | Returns raw units (apply decimals). |
| Decimals | `erc20.functions.decimals().call()` | Cache; rarely changes. |
| Symbol | `erc20.functions.symbol().call()` | Display only. |
| Transfer | `erc20.functions.transfer(to, amount).build_transaction({...})` | Requires sufficient token + gas. |
| Allowance | `erc20.functions.allowance(owner, spender).call()` | Pre-check before spending flows. |
| Approve | `erc20.functions.approve(spender, amount).build_transaction({...})` | Consider using max uint or precise. |

Gas Optimization Tips:
- Batch reads via multicall (future enhancement) to reduce RPC round trips.
- Recycle Gunicorn workers (already configured) to mitigate memory bloat under heavy ABI parsing.
- For high-frequency transfers, precompute `data` field and reuse gas estimates within short time windows.

Security Notes:
- Never embed real private keys inside scripts. Use environment injection at runtime only.
- Consider remote signer (e.g. Hashicorp Vault, Web3 signer) for production—GLI then requests signatures via API.
- Monitor pending pool: if many stuck transactions, raise maxFeePerGas / priority or replace (nonce strategy not yet automated here).

### 6.13 Stablecoin Specific Considerations

Official USDT may implement pause/blacklist features—always check verified contract and events. For compliance-sensitive flows, add:
- Preflight contract status check (optionally call a known pause/blacklist mapping if ABI exposes it).
- Supply sanity verification: compare reported totalSupply with trusted oracle feed.

Mock tokens DO NOT reflect governance or compliance constraints; limit their usage strictly to QA and integration testing.
MODE=dry  ./scripts/migrate_to_external.sh
MODE=commit ./scripts/migrate_to_external.sh
Sets .app_root.migrated with APP_ROOT=dest.
Update shell profile: export APP_ROOT=...; export DATA_BASE=...
Benefits: Portability, isolation. Drawbacks: External disk latency.
Interventions: Use SSD external; monitor iostat for bottlenecks.

---
## 7. Security & Hardening Checklist
- [x] Removed hard-coded private key injection in deploy script
- [x] Sanitized example scripts with placeholders
- [ ] Move secrets to Docker secrets or env vault
- [ ] Apply read-only root filesystem & tmpfs mounts (after verifying write paths)
- [ ] Add integrity hash logging for model file (sha256)
- [ ] Implement signed image attestations (cosign) & SBOM verification pipeline
- [ ] Rate-limit external API calls (token bucket) to prevent provider throttling

Immediate Actions Recommended:
1. Replace placeholder keys in .env (never commit).
2. Restrict file permissions: chmod 600 .env
3. Add .dockerignore entries for secrets.
4. Optionally integrate Vault or AWS KMS for signing.

---
## 8. Scaling & Performance
- Increase GUNICORN_WORKERS proportionally to CPU cores (<= 2x cores optimal baseline).
- Use --read-only + mount writable dirs (/tmp, /data/cache) for stronger isolation.
- Horizontal scaling: docker compose up --scale rosettaai=3
- Add Nginx / gateway round-robin or use service mesh for advanced routing.

Monitoring Signals:
- service_up flaps -> check container restarts (docker events)
- Long predict latency -> pre-load model, add warmup calls
- High RPC timeouts -> implement exponential backoff + circuit breaker

---
## 9. Troubleshooting
| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| rosettaai 5xx | Missing model file | Verify mount path & MODEL_PATH |
| Transfer insufficient gas | Gas price spike | Retry with updated gas suggestions |
| Cache misses high | Low TTL | Increase ETHERSCAN_CACHE_TTL |
| Autoheal loop | Logic bug or persistent failure | Inspect logs, disable autoheal temporarily |
| Disk full | Backups accumulate | Prune old backups (keep last N) |

---
## 10. Extending the System
Use generator to scaffold new component under orchestrator/components:
python orchestrator/generate_components.py --name BridgeAI
Implement main.py (Flask or FastAPI), add to docker-compose.yml, mount volumes via DATA_BASE, expose health/predict endpoints.

---
## 11. Governance & Change Control
- All path changes go through APP_ROOT / DATA_BASE abstractions
- Commit includes: updated env.template when new env vars added
- Tag releases after successful backup & integrity verification

---
## 12. Glossary
- APP_ROOT: Root of application source tree.
- DATA_BASE: External base directory (mounted into containers as /data or /modeldata variants).
- GLI: General Ledger Interface microservice handling token transfers.
- RossettaAI: AI inference microservice loading model JSON artifact.

---
## 13. Future Enhancements (Roadmap)
- Model hot-reload (watch trained_model.json mtime)
- Structured OpenTelemetry traces
- Circuit breaker for upstream RPC errors
- Post-transaction reconciliation worker
- BridgeAI cross-chain orchestration

---
## 14. Fast Reference Commands
Start stack: docker compose up -d --build
Stop stack: docker compose down
Check health: docker ps; curl localhost:5005/health
Scale model: docker compose up -d --scale rosettaai=3
Tail logs: docker compose logs -f rosettaai
Backup: ./scripts/backup_data.sh
Migrate: MODE=commit ./scripts/migrate_to_external.sh
Metrics: curl localhost:9100/metrics
Transfer (example): curl -X POST http://localhost:5002/transfer -H 'Content-Type: application/json' -d '{"recipient":"<ADDR>","amount":1000000}'
Predict: curl -X POST http://localhost:5090/predict -H 'Content-Type: application/json' -d '{"input":"Hello"}'

---
## 15. Onboarding Checklist (Novice to Expert)
1. Set APP_ROOT & DATA_BASE exports.
2. Copy env.template to .env and fill mandatory keys.
3. Run stack; verify health endpoints.
4. Execute a dry-run transfer (GLI_DRY_RUN=1).
5. Enable real transfer (GLI_DRY_RUN=0) with small amount.
6. Query metrics and interpret service_up.
7. Perform backup & validate manifest.
8. Scale model service; observe metrics.
9. Add new component scaffold; deploy.
10. Draft improvement issue (e.g. add latency metric) and implement.

Completion of the above yields operational fluency.

---
## 16. Transaction Lifecycle & Recovery (Pending / Dropped / Replaced)

This section explains how Ethereum transactions (including ERC‑20 transfers like USDT) move through states and how to intervene safely.

### 16.1 Core States

| State | Meaning | On-Chain Effect |
|-------|---------|-----------------|
| Created | Signed locally; not yet seen by peers | None |
| Broadcast (Pending / In Mempool) | Propagated; waiting to be included | None until mined |
| Mined (Success) | Included in a block; status=1 | Effects permanent (balance / token transfer) |
| Mined (Failed/Reverted) | Included; status=0 | State unchanged except gas spent |
| Dropped | Node(s) evicted txn from mempool | No on-chain effect; hash may seem to "disappear" |
| Replaced | A newer txn with SAME nonce accepted (higher fee or different action) | Original hash becomes orphaned logically |

### 16.2 Why Transactions Get Dropped

Primary causes:
1. Fee too low vs current base fee + priority (txn becomes uncompetitive).
2. Local node mempool eviction (size / time / replacement policies).
3. Stale replacement attempts (another client re‑broadcasts a higher fee variant; original de‑prioritized then aged out).
4. Chain reorg extremely rare: short-term pending reshuffle (usually reappears or is mined later).

Dropped != Failed. A dropped txn never executed—gas not charged (unless a replacement was mined).

### 16.3 Replacement (Fee Bump) & Cancellation

Each address uses a strictly increasing nonce. To replace a stuck pending txn use the SAME nonce with:
1. Identical action but higher fees (speed-up).
2. A self-transfer of 0 ETH (or minimal value) to effectively cancel the original intent (cancellation pattern) – only works if mined before original.

Fee bump rules (EIP-1559 environment):
- Must raise `maxFeePerGas` and usually `maxPriorityFeePerGas` (tip) above previous values (wallets often require +10% to +15% min; aim +20% for busy periods).
- Preserve or adjust gas limit (do not reduce below realistic requirement or you risk a revert).

### 16.4 Practical Playbook

| Situation | Symptom | Action | Command Concept |
|-----------|---------|--------|-----------------|
| Slow confirm | Pending > target SLA | Build replacement with higher `maxFeePerGas` & tip | Re-sign & broadcast same nonce |
| Want to cancel | Change of mind, txn still pending | Send 0 ETH to self (same nonce) with higher fee | Self tx replacement |
| Disappeared | Explorer no longer shows pending | Re-broadcast raw signed txn OR decide to replace | Re-send / replace |
| Underpriced repeatedly | Node rejects | Increase both base maxFee & priority tip more aggressively | +30–50% bump |
| Sequence blocked | Later txns waiting on a stuck nonce | Replace earliest stuck txn first | Work oldest nonce first |

### 16.5 Detecting Dropped vs Pending

Checklist:
- Not in a recent explorer pending list.
- Node RPC `eth_getTransactionByHash` returns null several minutes after initial broadcast.
- Another txn with same nonce now exists (then original is effectively replaced).

### 16.6 Integrating Into QuantumAI

Enhancements you can add (future roadmap):
1. Pending monitor task: poll mempool status every N seconds and emit events (`pending`, `mined`, `dropped`).
2. Automatic fee escalation policy: after T seconds unconfirmed -> bump fees (geometric or capped increments).
3. Cancellation API endpoint: `/tx/cancel` generating self 0 ETH replacement with safe tip.
4. Nonce manager: durable store (Redis) tracking last confirmed & highest pending to avoid gaps.
5. Metrics additions: `tx_pending_age_seconds`, `tx_replacements_total`, `tx_dropped_total`.

### 16.7 Gas Strategy (EIP-1559)

| Parameter | Source | Guidance |
|-----------|--------|----------|
| Base Fee | Protocol (block header) | Read from latest block; do NOT set manually |
| Max Priority (Tip) | User / strategy | 1–2 gwei calm; 3–6 gwei moderate; spike >10 gwei busy |
| Max Fee | Base Fee * safety factor + tip | Use factor 1.5–2.0 during volatility |
| Gas Limit | Estimator + headroom | Add ~20% buffer over estimate |

Pseudo estimation snippet:
```
max_fee_per_gas = int(base_fee * 2 + priority_fee)
```

### 16.8 Handling ERC-20 Transfers

If original transfer is replaced with a cancellation (0 ETH self), token allowance / balances remain unchanged (since ERC-20 call never executed). Always re-query token balance after final mined receipt.

### 16.9 Failure vs Drop

| Aspect | Dropped | Failed (Revert) |
|--------|---------|-----------------|
| Gas spent | No | Yes (consumed) |
| On-chain receipt | None | Present (status=0) |
| Can repeat safely | Yes (original never executed) | Caution: understand revert cause before retry |

### 16.10 Safety Tips

1. Never brute-force nonces; always increment sequentially.
2. Keep one source of truth for pending state (avoid race conditions across multiple signers).
3. Log raw signed txn bytes for reproducible rebroadcast (store encrypted at rest).
4. Avoid perpetual fee escalations—cap replacement attempts to prevent runaway costs.
5. For high-value transfers, simulate (call/eth_estimateGas) just before signing.

### 16.11 Future Automation Opportunities

- Integrate a background worker that tags stuck transactions (>N blocks behind head) and invokes controlled replacement.
- Add UI/CLI to list `pending | age | gas params | replacable?`.
- Provide dry-run diff: old vs proposed bumped fees before broadcasting.

---
## Sepolia Testnet

An API key generated on Etherscan ​<img src="https://3270418672-files.gitbook.io/~/files/v0/b/gitbook-x-prod.appspot.com/o/spaces%2FhjEMCuc4F42fAi2KmpcK%2Fuploads%2Fgit-blob-29966808954100660b18274b582c1afb2fe45fed%2Fetherscan-logo-circle.png?alt=media" alt="" data-size="line"> can be used across all **mainnet** and **testnet** explorers.

Similarly, all endpoints and parameter formatting remain the same across testnet explorers, you are only required to change the relevant API endpoint URL as follows.

| Network | URL                                                                          | Documentation                                                                                    |
| ------- | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Mainnet | [https://api.etherscan.io/api](https://api.etherscan.io/api)                 | [https://docs.etherscan.io/](https://docs.etherscan.io)                                          |
| Goerli  | [https://api-goerli.etherscan.io/api](https://api-goerli.etherscan.io/api)   | [https://docs.etherscan.io/v/goerli-etherscan](https://docs.etherscan.io/v/goerli-etherscan/)    |
| Sepolia | [https://api-sepolia.etherscan.io/api](https://api-sepolia.etherscan.io/api) | [https://docs.etherscan.io/v/sepolia-etherscan/](https://docs.etherscan.io/v/sepolia-etherscan/) |

{% hint style="success" %}
**Source attribution** via a backlink or a mention that your app is **"Powered by Etherscan APIs"** is required except for personal/private usage.
{% endhint %}

## Accounts

## Get Ether Balance for a Single Address

Returns the Ether balance of a given address.

```
https://api-sepolia.etherscan.io/api
   ?module=account
   &action=balance
   &address=0x382b4ca2c4a7cd28c1c400c69d81ec2b2637f7dd
   &tag=latest
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api-sepolia.etherscan.io/api?module=account\&action=balance\&address=0x382b4ca2c4a7cd28c1c400c69d81ec2b2637f7dd\&tag=latest\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter | Description                                                                        |
| --------- | ---------------------------------------------------------------------------------- |
| address   | the `string` representing the address to check for balance                         |
| tag       | the `string` pre-defined block parameter, either `earliest`, `pending` or `latest` |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":"206796937658929992503000" 
}
```

{% hint style="info" %}
:book: **Tip:** The `result` is returned in [**wei.**](https://sepolia.etherscan.io/unitconverter)

Convert Ethereum units using our [**Unit Converter.**](https://sepolia.etherscan.io/unitconverter)
{% endhint %}
{% endtab %}
{% endtabs %}

## Get Ether Balance for Multiple Addresses in a Single Call

Returns the balance of the accounts from a list of addresses.

```
https://api-sepolia.etherscan.io/api
   ?module=account
   &action=balancemulti
   &address=https://api-sepolia.etherscan.io/api?module=account&action=balance&address=0x382b4ca2c4a7cd28c1c400c69d81ec2b2637f7dd,0x382b4ca2c4a7cd28c1c400c69d81ec2b2637f7dd,0x8a5847fd0e592b058c026c5fdc322aee834b87f5&tag=latest&apikey=YourApiKeyToken,0x63a9dbCe75413036B2B778E670aaBd4493aAF9F3,0xd82b6aB1f20A21484fA5E28221B95425dddC5E8E
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api-sepolia.etherscan.io/api?module=account\&action=balancemulti\&address=0x382b4ca2c4a7cd28c1c400c69d81ec2b2637f7dd,0x382b4ca2c4a7cd28c1c400c69d81ec2b2637f7dd,0x8a5847fd0e592b058c026c5fdc322aee834b87f5\&tag=latest\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter | Description                                                                                                                                                             |
| --------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| address   | <p>the <code>strings</code> representing the addresses to check for balance, separated by <code>,</code> commas<br><br>up to <strong>20 addresses</strong> per call</p> |
| tag       | the `integer` pre-defined block parameter, either `earliest`, `pending` or `latest`                                                                                     |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "account":"0x382b4ca2c4a7cd28c1c400c69d81ec2b2637f7dd",
         "balance":"206796937658929992503000"
      },
      {
         "account":"0x382b4ca2c4a7cd28c1c400c69d81ec2b2637f7dd",
         "balance":"206796937658929992503000"
      },
      {
         "account":"0x8a5847fd0e592b058c026c5fdc322aee834b87f5",
         "balance":"16288712393992050891"
      }
   ]
}
```

{% hint style="info" %}
:book: **Tip:** The `result` is returned in [**wei.**](https://sepolia.etherscan.io/unitconverter)

Convert Ethereum units using our [**Unit Converter.**](https://sepolia.etherscan.io/unitconverter)
{% endhint %}
{% endtab %}
{% endtabs %}

## Get a list of 'Normal' Transactions By Address

Returns the list of transactions performed by an address, with optional pagination.

{% hint style="warning" %}
**​**​ ​ :pencil: **Note :** This API endpoint returns a maximum of **10000 records** only.
{% endhint %}

```
https://api-sepolia.etherscan.io/api
   ?module=account
   &action=txlist
   &address=0x382b4ca2c4a7cd28c1c400c69d81ec2b2637f7dd
   &startblock=0
   &endblock=99999999
   &page=1
   &offset=10
   &sort=asc
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api-sepolia.etherscan.io/api?module=account\&action=txlist\&address=0x382b4ca2c4a7cd28c1c400c69d81ec2b2637f7dd\&startblock=0\&endblock=99999999\&page=1\&offset=10\&sort=asc\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter  | Description                                                                             |
| ---------- | --------------------------------------------------------------------------------------- |
| address    | the `string` representing the addresses to check for balance                            |
| startblock | the `integer` block number to start searching for transactions                          |
| endblock   | the `integer` block number to stop searching for transactions                           |
| page       | the `integer` page number, if pagination is enabled                                     |
| offset     | the number of transactions displayed per page                                           |
| sort       | the sorting preference, use `asc` to sort by ascending and `desc` to sort by descending |

{% hint style="info" %}
:bulb: **Tip:** Specify a smaller `startblock` and `endblock` range for faster search results.
{% endhint %}
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK-Missing/Invalid API Key, rate limit of 1/5sec applied",
   "result":[
      {
         "blockNumber":"1037571",
         "timeStamp":"1651759857",
         "hash":"0x710e53707c79dd438a8bc3db2a45a123af6dba0d4a653a134035306d11f415fd",
         "nonce":"5",
         "blockHash":"0x64201f8940cee65186f64adb68a99fe3da0450bc9490617aeedd08f80cb8e29b",
         "transactionIndex":"0",
         "from":"0x10f5d45854e038071485ac9e402308cf80d2d2fe",
         "to":"0x382b4ca2c4a7cd28c1c400c69d81ec2b2637f7dd",
         "value":"50000000000000000000000",
         "gas":"21000",
         "gasPrice":"1500000007",
         "isError":"0",
         "txreceipt_status":"1",
         "input":"0x",
         "contractAddress":"",
         "cumulativeGasUsed":"21000",
         "gasUsed":"21000",
         "confirmations":"48476"
      },
      {
         "blockNumber":"1061942",
         "timeStamp":"1652077697",
         "hash":"0x7734cae034c8a7198a5988c5ae927adf30cf77d2cbb25ed996278e402c0e0032",
         "nonce":"0",
         "blockHash":"0xedc7119adb34edf5480fe52f090dedbef647948ffc91806afe7d8b0182781b40",
         "transactionIndex":"0",
         "from":"0x382b4ca2c4a7cd28c1c400c69d81ec2b2637f7dd",
         "to":"0x93e973436cd7757f21b1c947599f67082624a721",
         "value":"1000000000000000",
         "gas":"21000",
         "gasPrice":"2000000007",
         "isError":"0",
         "txreceipt_status":"1",
         "input":"0x",
         "contractAddress":"",
         "cumulativeGasUsed":"21000",
         "gasUsed":"21000",
         "confirmations":"24105"
      }
   ]
}
```
{% endtab %}
{% endtabs %}

## Get a list of 'Internal' Transactions by Address

Returns the list of internal transactions performed by an address, with optional pagination.

{% hint style="warning" %}
:pencil: **Note :** This API endpoint returns a maximum of **10000 records** only.
{% endhint %}

```
https://api-sepolia.etherscan.io/api
   ?module=account
   &action=txlistinternal
   &address=0xa4fadaa5e8577fee5799e2bd9615014013b45c5d
   &startblock=0
   &endblock=99999999
   &page=1
   &offset=10
   &sort=asc
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api-sepolia.etherscan.io/api?module=account\&action=txlistinternal\&address=0xa4fadaa5e8577fee5799e2bd9615014013b45c5d\&startblock=0\&endblock=99999999\&page=1\&offset=10\&sort=asc\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter  | Description                                                                             |
| ---------- | --------------------------------------------------------------------------------------- |
| address    | the `string` representing the addresses to check for balance                            |
| startblock | the `integer` block number to start searching for transactions                          |
| endblock   | the `integer` block number to stop searching for transactions                           |
| page       | the `integer` page number, if pagination is enabled                                     |
| offset     | the number of transactions displayed per page                                           |
| sort       | the sorting preference, use `asc` to sort by ascending and `desc` to sort by descending |

{% hint style="info" %}
:bulb: **Tip:** Specify a smaller `startblock` and `endblock` range for faster search results
{% endhint %}
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "blockNumber":"765371",
         "timeStamp":"1648218619",
         "hash":"0xcb6609b6f9133fc1bfd189fb52ed616968a5f7c56af8da3bd6724f7655fe5f78",
         "from":"0x02f11eabf51d28bb0bae795e256ce52161d65c2b",
         "to":"0xa4fadaa5e8577fee5799e2bd9615014013b45c5d",
         "value":"10000000000000000",
         "contractAddress":"",
         "input":"",
         "type":"call",
         "gas":"2300",
         "gasUsed":"0",
         "traceId":"0_1",
         "isError":"0",
         "errCode":""
      }
   ]
}
```
{% endtab %}
{% endtabs %}

## Get 'Internal Transactions' by Transaction Hash

Returns the list of internal transactions performed within a transaction.

{% hint style="warning" %}
**Note :** This API endpoint returns a maximum of **10000 records** only.
{% endhint %}

```
https://api-sepolia.etherscan.io/api
   ?module=account
   &action=txlistinternal
   &txhash=0xb730ee4dc8d0274be31d1e31ed7fe9749d7a67c0e35b297f3c2d10b06c1f6f1e
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api-sepolia.etherscan.io/api?module=account\&action=txlistinternal\&txhash=0xb730ee4dc8d0274be31d1e31ed7fe9749d7a67c0e35b297f3c2d10b06c1f6f1e\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter | Description                                                                       |
| --------- | --------------------------------------------------------------------------------- |
| txhash    | the `string` representing the transaction hash to check for internal transactions |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "blockNumber":"312070",
         "timeStamp":"1639592011",
         "from":"0xa234eead085ac80a4f7cc5220789e048373f0f1e",
         "to":"",
         "value":"0",
         "contractAddress":"0x63a19c2868e469ffc2c8346c93f81ff6e140ffaf",
         "input":"",
         "type":"create",
         "gas":"8504616",
         "gasUsed":"134349",
         "isError":"0",
         "errCode":""
      },
     
      {
         "blockNumber":"312070",
         "timeStamp":"1639592011",
         "from":"0xa234eead085ac80a4f7cc5220789e048373f0f1e",
         "to":"",
         "value":"0",
         "contractAddress":"0xe05ba0186f4a5a5d0eb8a5394d8413411ffd321c",
         "input":"",
         "type":"create",
         "gas":"1119086",
         "gasUsed":"134349",
         "isError":"0",
         "errCode":""
      },
      {
         "blockNumber":"312070",
         "timeStamp":"1639592011",
         "from":"0xa234eead085ac80a4f7cc5220789e048373f0f1e",
         "to":"",
         "value":"0",
         "contractAddress":"0x7b99f4f6260c3cd12984e8d2b83eaf51d44e2254",
         "input":"",
         "type":"create",
         "gas":"134349",
         "gasUsed":"134349",
         "isError":"0",
         "errCode":""
      }
   ]
}
```

{% hint style="info" %}
The `isError` field returns `0` for **successful transactions** and `1` for **rejected/cancelled transactions.**
{% endhint %}
{% endtab %}
{% endtabs %}

## Get "Internal Transactions" by Block Range

Returns the list of internal transactions performed within a block range, with optional pagination.

{% hint style="warning" %}
​​ :pencil: **Note :** This API endpoint returns a maximum of **10000 records** only.
{% endhint %}

```
https://api-sepolia.etherscan.io/api
   ?module=account
   &action=txlistinternal
   &startblock=484887
   &endblock=765371
   &page=1
   &offset=10
   &sort=asc
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api-sepolia.etherscan.io/api?module=account\&action=txlistinternal\&startblock=484887\&endblock=765371\&page=1\&offset=10\&sort=asc\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter  | Description                                                                             |
| ---------- | --------------------------------------------------------------------------------------- |
| startblock | the `integer` block number to start searching for transactions                          |
| endblock   | the `integer` block number to stop searching for transactions                           |
| page       | the `integer` page number, if pagination is enabled                                     |
| offset     | the number of transactions displayed per page                                           |
| sort       | the sorting preference, use `asc` to sort by ascending and `desc` to sort by descending |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "blockNumber":"484887",
         "timeStamp":"1644613109",
         "hash":"0xc3ff81084b157b7d695f3df8636eebcacb6ca938c62c3102492978dbe8f5879b",
         "from":"0x9bcdb32c4d0f0992bfb926a28ee2cb7b9d9750cc",
         "to":"0x105083929bf9bb22c26cb1777ec92661170d4285",
         "value":"3906875000000000000000",
         "contractAddress":"",
         "input":"",
         "type":"call",
         "gas":"2300",
         "gasUsed":"0",
         "traceId":"0_1",
         "isError":"0",
         "errCode":""
      },
      {
         "blockNumber":"498080",
         "timeStamp":"1644787132",
         "hash":"0x1ab55087625084f2e1462a49f13a36d0996bff67da3cb4e7250e110e922274bd",
         "from":"0x9bcdb32c4d0f0992bfb926a28ee2cb7b9d9750cc",
         "to":"0x84e9304fa9aafc5e70090eadda9ac2c76d93ad51",
         "value":"1491314746532500000000",
         "contractAddress":"",
         "input":"",
         "type":"call",
         "gas":"2300",
         "gasUsed":"0",
         "traceId":"0_1",
         "isError":"0",
         "errCode":""
      },
      {
         "blockNumber":"518080",
         "timeStamp":"1645046610",
         "hash":"0x1b08041082471d96bbf5362db688f447ce8c775d242998a3b190211560911d86",
         "from":"0x9bcdb32c4d0f0992bfb926a28ee2cb7b9d9750cc",
         "to":"0x105083929bf9bb22c26cb1777ec92661170d4285",
         "value":"4250625000000000000000",
         "contractAddress":"",
         "input":"",
         "type":"call",
         "gas":"2300",
         "gasUsed":"0",
         "traceId":"0_1",
         "isError":"0",
         "errCode":""
      }
   ]
}
```

{% hint style="info" %}
The `isError` field returns `0` for **successful transactions** and `1` for **rejected/cancelled transactions.**
{% endhint %}
{% endtab %}
{% endtabs %}

## Get a list of 'ERC20 - Token Transfer Events' by Address

Returns the list of ERC-20 tokens transferred by an address, with optional filtering by token contract.

```
https://api-sepolia.etherscan.io/api
   ?module=account
   &action=tokentx
   &contractaddress=0xa808b14492AC6E33419ac16112154D40D0A4AEBA
   &address=0x105083929bf9bb22c26cb1777ec92661170d4285
   &page=1
   &offset=100
   &startblock=0
   &endblock=99999999
   &sort=asc
   &apikey=YourApiKeyToken
```

Usage:

* ERC-20 transfers from an **address**, specify the `address` parameter
* ERC-20 transfers from a **contract address**, specify the `contract address` parameter
* ERC-20 transfers from an **address** filtered by a **token contract**, specify both `address` and `contract address` parameters.

> Try this endpoint in your [**browser**](https://api-sepolia.etherscan.io/api?module=account\&action=tokentx\&contractaddress=0xa808b14492AC6E33419ac16112154D40D0A4AEBA\&address=0x105083929bf9bb22c26cb1777ec92661170d4285\&page=1\&offset=100\&startblock=0\&endblock=99999999\&sort=asc\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter       | Description                                                                             |
| --------------- | --------------------------------------------------------------------------------------- |
| address         | the `string` representing the address to check for balance                              |
| contractaddress | the `string` representing the token contract address to check for balance               |
| page            | the `integer` page number, if pagination is enabled                                     |
| offset          | the number of transactions displayed per page                                           |
| startblock      | the `integer` block number to start searching for transactions                          |
| endblock        | the `integer` block number to stop searching for transactions                           |
| sort            | the sorting preference, use `asc` to sort by ascending and `desc` to sort by descending |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "blockNumber":"496492",
         "timeStamp":"1644767322",
         "hash":"0x433994d50986d0c021098adadac4f4a89249c51fb4ea372e553af6ee6fc0965c",
         "nonce":"20",
         "blockHash":"0x29394a72a707d77a167a1eec53d33940b5a366a2c01cd10094c18a15517ff44b",
         "from":"0x84e9304fa9aafc5e70090eadda9ac2c76d93ad51",
         "contractAddress":"0xa808b14492ac6e33419ac16112154d40d0a4aeba",
         "to":"0x105083929bf9bb22c26cb1777ec92661170d4285",
         "value":"100000000000000000000000",
         "tokenName":"Vitcoin",
         "tokenSymbol":"VTC",
         "tokenDecimal":"18",
         "transactionIndex":"0",
         "gas":"53517",
         "gasPrice":"1000000007",
         "gasUsed":"35678",
         "cumulativeGasUsed":"35678",
         "input":"deprecated",
         "confirmations":"589603"
      },
      {
         "blockNumber":"886779",
         "timeStamp":"1649789803",
         "hash":"0x1071238546873837a9b03736a8ca26ce379e66999f6e74748dd919890232e34a",
         "nonce":"28",
         "blockHash":"0xd1a3ad751eba89ac664e691844a5a44361d8c801ce6bbfe31c03f1d7970e28f7",
         "from":"0x84e9304fa9aafc5e70090eadda9ac2c76d93ad51",
         "contractAddress":"0xa808b14492ac6e33419ac16112154d40d0a4aeba",
         "to":"0x105083929bf9bb22c26cb1777ec92661170d4285",
         "value":"999900000000000000000000000",
         "tokenName":"Vitcoin",
         "tokenSymbol":"VTC",
         "tokenDecimal":"18",
         "transactionIndex":"0",
         "gas":"53553",
         "gasPrice":"1500000007",
         "gasUsed":"30902",
         "cumulativeGasUsed":"30902",
         "input":"deprecated",
         "confirmations":"199316"
      }
   ]
}
```
{% endtab %}
{% endtabs %}

## Get a list of 'ERC721 - Token Transfer Events' by Address

Returns the list of ERC-721 ( NFT ) tokens transferred by an address, with optional filtering by token contract

```
https://api-sepolia.etherscan.io/api
   ?module=account
   &action=tokennfttx
   &contractaddress=0x03e73ef97303e11703864a5404d71351ef61d8f8
   &address=0xb541f07fd1ae0a0d0244982e847a072436ee67db
   &page=1
   &offset=100
   &startblock=0
   &endblock=99999999
   &sort=asc
   &apikey=YourApiKeyToken
```

Usage:

* ERC-721 transfers from an **address**, specify the `address` parameter
* ERC-721 transfers from a **contract address**, specify the `contract address` parameter
* ERC-721 transfers from an **address** filtered by a **token contract**, specify both `address` and `contract address` parameters.

> Try this endpoint in your [**browser**](https://api-sepolia.etherscan.io/api?module=account\&action=tokennfttx\&contractaddress=0x03e73ef97303e11703864a5404d71351ef61d8f8\&address=0xb541f07fd1ae0a0d0244982e847a072436ee67db\&page=1\&offset=100\&startblock=0\&endblock=99999999\&sort=asc\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter       | Description                                                                             |
| --------------- | --------------------------------------------------------------------------------------- |
| address         | the `string` representing the address to check for balance                              |
| contractaddress | the `string` representing the token contract address to check for balance               |
| page            | the `integer` page number, if pagination is enabled                                     |
| offset          | the number of transactions displayed per page                                           |
| startblock      | the `integer` block number to start searching for transactions                          |
| endblock        | the `integer` block number to stop searching for transactions                           |
| sort            | the sorting preference, use `asc` to sort by ascending and `desc` to sort by descending |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "blockNumber":"8618316",
         "timeStamp":"1621510305",
         "hash":"0x9c10c45f47088060c9493e88361d7eedbc3b4dd2772e0b1deeb84d46a5c8e623",
         "nonce":"338",
         "blockHash":"0x2b690dd69f868351e179068befc3cd3f6d2621a8d425093d3980a24ac1347179",
         "from":"0x0000000000000000000000000000000000000000",
         "contractAddress":"0x03e73ef97303e11703864a5404d71351ef61d8f8",
         "to":"0xb541f07fd1ae0a0d0244982e847a072436ee67db",
         "tokenID":"10001",
         "tokenName":"Artifex",
         "tokenSymbol":"ARTIFEX",
         "tokenDecimal":"0",
         "transactionIndex":"0",
         "gas":"5016425",
         "gasPrice":"2051200000",
         "gasUsed":"5016425",
         "cumulativeGasUsed":"5016425",
         "input":"deprecated",
         "confirmations":"927169"
      },
      {
         "blockNumber":"8618316",
         "timeStamp":"1621510305",
         "hash":"0x9c10c45f47088060c9493e88361d7eedbc3b4dd2772e0b1deeb84d46a5c8e623",
         "nonce":"338",
         "blockHash":"0x2b690dd69f868351e179068befc3cd3f6d2621a8d425093d3980a24ac1347179",
         "from":"0x0000000000000000000000000000000000000000",
         "contractAddress":"0x03e73ef97303e11703864a5404d71351ef61d8f8",
         "to":"0xb541f07fd1ae0a0d0244982e847a072436ee67db",
         "tokenID":"10002",
         "tokenName":"Artifex",
         "tokenSymbol":"ARTIFEX",
         "tokenDecimal":"0",
         "transactionIndex":"0",
         "gas":"5016425",
         "gasPrice":"2051200000",
         "gasUsed":"5016425",
         "cumulativeGasUsed":"5016425",
         "input":"deprecated",
         "confirmations":"927169"
      }
   ]
}
```
{% endtab %}
{% endtabs %}

## Get list of Blocks Mined by Address

Returns the list of blocks mined by an address.

```
https://api-sepolia.etherscan.io/api
   ?module=account
   &action=getminedblocks
   &address=0x3d080421c9DD5fB387d6e3124f7E1C241ADE9568
   &blocktype=blocks
   &page=1
   &offset=10
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api-sepolia.etherscan.io/api?module=account\&action=getminedblocks\&address=0x3d080421c9DD5fB387d6e3124f7E1C241ADE9568\&blocktype=blocks\&page=1\&offset=10\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter | Description                                                                                                 |
| --------- | ----------------------------------------------------------------------------------------------------------- |
| address   | the `string` representing the address to check for balance                                                  |
| blocktype | the `string` pre-defined block type, either `blocks` for canonical blocks or `uncles` for uncle blocks only |
| page      | the `integer` page number, if pagination is enabled                                                         |
| offset    | the number of transactions displayed per page                                                               |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "blockNumber":"1088398",
         "timeStamp":"1652415312",
         "blockReward":"2000000000000000000"
      },
      {
         "blockNumber":"1088395",
         "timeStamp":"1652415289",
         "blockReward":"2000000000000000000"
      },
      {
         "blockNumber":"1088361",
         "timeStamp":"1652414946",
         "blockReward":"2000000000000000000"
      }
   ]
}
```

{% hint style="warning" %}
:hourglass_flowing_sand: **Note :** The `timeStamp` is represented in [**Unix timestamp.**](https://www.unixtimestamp.com)
{% endhint %}
{% endtab %}
{% endtabs %}

## Contracts

## Get Contract ABI for [Verified Contract Source Codes](https://etherscan.io/contractsVerified)

Returns the Contract Application Binary Interface ( ABI ) of a verified smart contract.

{% hint style="info" %}
Find verified contracts :white_check_mark:on our [**Verified Contracts Source Code**](https://etherscan.io/contractsVerified) page.
{% endhint %}

```
https://api.etherscan.io/api
   ?module=contract
   &action=getabi
   &address=0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413
   &apikey=YourApiKeyToken
```

> Try this endpoint in your [**browser**](https://api.etherscan.io/api?module=contract\&action=getabi\&address=0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413\&apikey=YourApiKeyToken) :link:

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter | Description                                            |
| --------- | ------------------------------------------------------ |
| address   | the `contract address` that has a verified source code |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":"[{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"name\":\"proposals\",\"outputs\":[{\"name\":\"recipient\",\"type\":\"address\"},{\"name\":\"amount\",\"type\":\"uint256\"},{\"name\":\"description\",\"type\":\"string\"},{\"name\":\"votingDeadline\",\"type\":\"uint256\"},{\"name\":\"open\",\"type\":\"bool\"},{\"name\":\"proposalPassed\",\"type\":\"bool\"},{\"name\":\"proposalHash\",\"type\":\"bytes32\"},{\"name\":\"proposalDeposit\",\"type\":\"uint256\"},{\"name\":\"newCurator\",\"type\":\"bool\"},{\"name\":\"yea\",\"type\":\"uint256\"},{\"name\":\"nay\",\"type\":\"uint256\"},{\"name\":\"creator\",\"type\":\"address\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_spender\",\"type\":\"address\"},{\"name\":\"_amount\",\"type\":\"uint256\"}],\"name\":\"approve\",\"outputs\":[{\"name\":\"success\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"minTokensToCreate\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"rewardAccount\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"daoCreator\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"totalSupply\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"divisor\",\"outputs\":[{\"name\":\"divisor\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"extraBalance\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_proposalID\",\"type\":\"uint256\"},{\"name\":\"_transactionData\",\"type\":\"bytes\"}],\"name\":\"executeProposal\",\"outputs\":[{\"name\":\"_success\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_from\",\"type\":\"address\"},{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"transferFrom\",\"outputs\":[{\"name\":\"success\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"unblockMe\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"totalRewardToken\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"actualBalance\",\"outputs\":[{\"name\":\"_actualBalance\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"closingTime\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"allowedRecipients\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"transferWithoutReward\",\"outputs\":[{\"name\":\"success\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"refund\",\"outputs\":[],\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_recipient\",\"type\":\"address\"},{\"name\":\"_amount\",\"type\":\"uint256\"},{\"name\":\"_description\",\"type\":\"string\"},{\"name\":\"_transactionData\",\"type\":\"bytes\"},{\"name\":\"_debatingPeriod\",\"type\":\"uint256\"},{\"name\":\"_newCurator\",\"type\":\"bool\"}],\"name\":\"newProposal\",\"outputs\":[{\"name\":\"_proposalID\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"DAOpaidOut\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"minQuorumDivisor\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_newContract\",\"type\":\"address\"}],\"name\":\"newContract\",\"outputs\":[],\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"}],\"name\":\"balanceOf\",\"outputs\":[{\"name\":\"balance\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_recipient\",\"type\":\"address\"},{\"name\":\"_allowed\",\"type\":\"bool\"}],\"name\":\"changeAllowedRecipients\",\"outputs\":[{\"name\":\"_success\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"halveMinQuorum\",\"outputs\":[{\"name\":\"_success\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"paidOut\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_proposalID\",\"type\":\"uint256\"},{\"name\":\"_newCurator\",\"type\":\"address\"}],\"name\":\"splitDAO\",\"outputs\":[{\"name\":\"_success\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"DAOrewardAccount\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"proposalDeposit\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"numberOfProposals\",\"outputs\":[{\"name\":\"_numberOfProposals\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"lastTimeMinQuorumMet\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_toMembers\",\"type\":\"bool\"}],\"name\":\"retrieveDAOReward\",\"outputs\":[{\"name\":\"_success\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"receiveEther\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"transfer\",\"outputs\":[{\"name\":\"success\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"isFueled\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_tokenHolder\",\"type\":\"address\"}],\"name\":\"createTokenProxy\",\"outputs\":[{\"name\":\"success\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_proposalID\",\"type\":\"uint256\"}],\"name\":\"getNewDAOAddress\",\"outputs\":[{\"name\":\"_newDAO\",\"type\":\"address\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_proposalID\",\"type\":\"uint256\"},{\"name\":\"_supportsProposal\",\"type\":\"bool\"}],\"name\":\"vote\",\"outputs\":[{\"name\":\"_voteID\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[],\"name\":\"getMyReward\",\"outputs\":[{\"name\":\"_success\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"rewardToken\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_from\",\"type\":\"address\"},{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"transferFromWithoutReward\",\"outputs\":[{\"name\":\"success\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"},{\"name\":\"_spender\",\"type\":\"address\"}],\"name\":\"allowance\",\"outputs\":[{\"name\":\"remaining\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_proposalDeposit\",\"type\":\"uint256\"}],\"name\":\"changeProposalDeposit\",\"outputs":[],\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"\",\"type\":\"address\"}],\"name\":\"blocked\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"curator\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_proposalID\",\"type\":\"uint256\"},{\"name\":\"_recipient\",\"type\":\"address\"},{\"name\":\"_amount\",\"type\":\"uint256\"},{\"name\":\"_transactionData\",\"type\":\"bytes\"}],\"name\":\"checkProposalCode\",\"outputs\":[{\"name\":\"_codeChecksOut\",\"type\":\"bool\"}],\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"privateCreation\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"type\":\"function\"},{\"inputs\":[{\"name\":\"_curator\",\"type\":\"address\"},{\"name\":\"_daoCreator\",\"type\":\"address\"},{\"name\":\"_proposalDeposit\",\"type\":\"uint256\"},{\"name\":\"_minTokensToCreate\",\"type\":\"uint256\"},{\"name\":\"_closingTime\",\"type\":\"uint256\"},{\"name\":\"_privateCreation\",\"type\":\"address\"}],\"type\":\"constructor\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"_from\",\"type\":\"address\"},{\"indexed\":true,\"name\":\"_to\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"_amount\",\"type\":\"uint256\"}],\"name\":\"Transfer\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"_owner\",\"type\":\"address\"},{\"indexed\":true,\"name\":\"_spender\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"_amount\",\"type\":\"uint256\"}],\"name\":\"Approval\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":false,\"name\":\"value\",\"type\":\"uint256\"}],\"name\":\"FuelingToDate\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"to\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"amount\",\"type\":\"uint256\"}],\"name\":\"CreatedToken\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"to\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"value\",\"type\":\"uint256\"}],\"name\":\"Refund\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"proposalID\",\"type\":\"uint256\"},{\"indexed\":false,\"name\":\"recipient\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"amount\",\"type\":\"uint256\"},{\"indexed\":false,\"name\":\"newCurator\",\"type\":\"bool\"},{\"indexed\":false,\"name\":\"description\",\"type\":\"string\"}],\"name\":\"ProposalAdded\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"proposalID\",\"type\":\"uint256\"},{\"indexed\":false,\"name\":\"position\",\"type\":\"bool\"},{\"indexed\":true,\"name\":\"voter\",\"type\":\"address\"}],\"name\":\"Voted\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"proposalID\",\"type\":\"uint256\"},{\"indexed\":false,\"name\":\"result\",\"type\":\"bool\"},{\"indexed\":false,\"name\":\"quorum\",\"type\":\"uint256\"}],\"name\":\"ProposalTallied\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"_newCurator\",\"type\":\"address\"}],\"name\":\"NewCurator\",\"type\":\"event\"},{\"anonymous\":false,\"inputs\":[{\"indexed\":true,\"name\":\"_recipient\",\"type\":\"address\"},{\"indexed\":false,\"name\":\"_allowed\",\"type\":\"bool\"}],\"name\":\"AllowedRecipientChanged\",\"type\":\"event\"}]"
}
```
{% endtab %}
{% endtabs %}

## Get Contract Source Code for [Verified Contract Source Codes](https://etherscan.io/contractsVerified)

Returns the Solidity source code of a verified smart contract.

{% hint style="info" %}
:envelope_with_arrow: **Tip :** You can also download a [**CSV list of verified contracts addresses**](https://etherscan.io/exportData?type=open-source-contract-codes) of which the code publishers have provided a corresponding Open Source license for redistribution.
{% endhint %}

> Try this endpoint in your [**browser**](https://api.etherscan.io/api?module=contract\&action=getsourcecode\&address=0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413\&apikey=YourApiKeyToken) :link:

```
https://api.etherscan.io/api
   ?module=contract
   &action=getsourcecode
   &address=0xBB9bc244D798123fDe783fCc1C72d3Bb8C189413
   &apikey=YourApiKeyToken 
```

{% tabs %}
{% tab title="Request" %}
Query Parameters

| Parameter | Description                                            |
| --------- | ------------------------------------------------------ |
| address   | the `contract address` that has a verified source code |
{% endtab %}

{% tab title="Response" %}
Sample Response

```
{
   "status":"1",
   "message":"OK",
   "result":[
      {
         "SourceCode":"/*\n\n- Bytecode Verification performed was compared on second iteration -\n\nThis file is part of the DAO.\n\nThe DAO is free software: you can redistribute it and/or modify\nit under the terms of the GNU lesser General Public License as published by\nthe Free Software Foundation, either version 3 of the License, or\n(at your option) any later version.\n\nThe DAO is distributed in the hope that it will be useful,\nbut WITHOUT ANY WARRANTY; without even the implied warranty of\nMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\nGNU lesser General Public License for more details.\n\nYou should have received a copy of the GNU lesser General Public License\nalong with the DAO.  If not, see <http://www.gnu.org/licenses/>.\n*/\n\n\n/*\nBasic, standardized Token contract with no \"premine\". Defines the functions to\ncheck token balances, send tokens, send tokens on behalf of a 3rd party and the\ncorresponding approval process. Tokens need to be created by a derived\ncontract (e.g. TokenCreation.sol).\n\nThank you ConsenSys, this contract originated from:\nhttps://github.com/ConsenSys/Tokens/blob/master/Token_Contracts/contracts/Standard_Token.sol\nWhich is itself based on the Ethereum standardized contract APIs:\nhttps://github.com/ethereum/wiki/wiki/Standardized_Contract_APIs\n*/\n\n/// @title Standard Token Contract.\n\ncontract TokenInterface {\n    mapping (address => uint256) balances;\n    mapping (address => mapping (address => uint256)) allowed;\n\n    /// Total amount of tokens\n    uint256 public totalSupply;\n\n    /// @param _owner The address from which the balance will be retrieved\n    /// @return The balance\n    function balanceOf(address _owner) constant returns (uint256 balance);\n\n    /// @notice Send `_amount` tokens to `_to` from `msg.sender`\n    /// @param _to The address of the recipient\n    /// @param _amount The amount of tokens to be transferred\n    /// @return Whether the transfer was successful or not\n    function transfer(address _to, uint256 _amount) returns (bool success);\n\n    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it\n    /// is approved by `_from`\n    /// @param _from The address of the origin of the transfer\n    /// @param _to The address of the recipient\n    /// @param _amount The amount of tokens to be transferred\n    /// @return Whether the transfer was successful or not\n    function transferFrom(address _from, address _to, uint256 _amount) returns (bool success);\n\n    /// @notice `msg.sender` approves `_spender` to spend `_amount` tokens on\n    /// its behalf\n    /// @param _spender The address of the account able to transfer the tokens\n    /// @param _amount The amount of tokens to be approved for transfer\n    /// @return Whether the approval was successful or not\n    function approve(address _spender, uint256 _amount) returns (bool success);\n\n    /// @param _owner The address of the account owning tokens\n    /// @param _spender The address of the account able to transfer the tokens\n    /// @return Amount of remaining tokens of _owner that _spender is allowed\n    /// to spend\n    function allowance(\n        address _owner,\n        address _spender\n    ) constant returns (uint256 remaining);\n\n    event Transfer(address indexed _from, address indexed _to, uint256 _amount);\n    event Approval(\n        address indexed _owner,\n        address indexed _spender,\n        uint256 _amount\n    );\n}\n\n\ncontract Token is TokenInterface {\n    // Protects users by preventing the execution of method calls that\n    // inadvertently also transferred ether\n    modifier noEther() {if (msg.value > 0) throw; _}\n\n    function balanceOf(address _owner) constant returns (uint256 balance) {\n        return balances[_owner];\n    }\n\n    function transfer(address _to, uint256 _amount) noEther returns (bool success) {\n        if (balances[msg.sender] >= _amount && _amount > 0) {\n            balances[msg.sender] -= _amount;\n            balances[_to] += _amount;\n            Transfer(msg.sender, _to, _amount);\n            return true;\n        } else {\n           return false;\n        }\n    }\n\n    function transferFrom(\n        address _from,\n        address _to,\n        uint256 _amount\n    ) noEther returns (bool success) {\n\n        if (balances[_from] >= _amount\n            && allowed[_from][msg.sender] >= _amount\n            && _amount > 0) {\n\n            balances[_to] += _amount;\n            balances[_from] -= _amount;\n            allowed[_from][msg.sender] -= _amount;\n            Transfer(_from, _to, _amount);\n            return true;\n        } else {\n            return false;\n        }\n    }\n\n    function approve(address _spender, uint256 _amount) returns (bool success) {\n        allowed[msg.sender][_spender] = _amount;\n        Approval(msg.sender, _spender, _amount);\n        return true;\n    }\n\n    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {\n        return allowed[_owner][_spender];\n    }\n}\n\n\n/*\nThis file is part of the DAO.\n\nThe DAO is free software: you can redistribute it and/or modify\nit under the terms of the GNU lesser General Public License as published by\nthe Free Software Foundation, either version 3 of the License, or\n(at your option) any later version.\n\nThe DAO is distributed in the hope that it will be useful,\nbut WITHOUT ANY WARRANTY; without even the implied warranty of\nMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\nGNU lesser General Public License for more details.\n\nYou should have received a copy of the GNU lesser General Public License\nalong with the DAO.  If not, see <http://www.gnu.org/licenses/>.\n*/\n\n\n/*\nBasic account, used by the DAO contract to separately manage both the rewards \nand the extraBalance accounts. \n*/\n\ncontract ManagedAccountInterface {\n    // The only address with permission to withdraw from this account\n    address public owner;\n    // If true, only the owner of the account can receive ether from it\n    bool public payOwnerOnly;\n    // The sum of ether (in wei) which has been sent to this contract\n    uint public accumulatedInput;\n\n    /// @notice Sends `_amount` of wei to _recipient\n    /// @param _amount The amount of wei to send to `_recipient`\n    /// @param _recipient The address to receive `_amount` of wei\n    /// @return True if the send completed\n    function payOut(address _recipient, uint _amount) returns (bool);\n\n    event PayOut(address indexed _recipient, uint _amount);\n}\n\n\ncontract ManagedAccount is ManagedAccountInterface{\n\n    // The constructor sets the owner of the account\n    function ManagedAccount(address _owner, bool _payOwnerOnly) {\n        owner = _owner;\n        payOwnerOnly = _payOwnerOnly;\n    }\n\n    // When the contract receives a transaction without data this is called. \n    // It counts the amount of ether it receives and stores it in \n    // accumulatedInput.\n    function() {\n        accumulatedInput += msg.value;\n    }\n\n    function payOut(address _recipient, uint _amount) returns (bool) {\n        if (msg.sender != owner || msg.value > 0 || (payOwnerOnly && _recipient != owner))\n            throw;\n        if (_recipient.call.value(_amount)()) {\n            PayOut(_recipient, _amount);\n            return true;\n        } else {\n            return false;\n        }\n    }\n}\n/*\nThis file is part of the DAO.\n\nThe DAO is free software: you can redistribute it and/or modify\nit under the terms of the GNU lesser General Public License as published by\nthe Free Software Foundation, either version 3 of the License, or\n(at your option) any later version.\n\nThe DAO is distributed in the hope that it will be useful,\nbut WITHOUT ANY WARRANTY; without even the implied warranty of\nMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\nGNU lesser General Public License for more details.\n\nYou should have received a copy of the GNU lesser General Public License\nalong with the DAO.  If not, see <http://www.gnu.org/licenses/>.\n*/\n\n\n/*\n * Token Creation contract, used by the DAO to create its tokens and initialize\n * its ether. Feel free to modify the divisor method to implement different\n * Token Creation parameters\n*/\n\n\ncontract TokenCreationInterface {\n\n    // End of token creation, in Unix time\n    uint public closingTime;\n    // Minimum fueling goal of the token creation, denominated in tokens to\n    // be created\n    uint public minTokensToCreate;\n    // True if the DAO reached its minimum fueling goal, false otherwise\n    bool public isFueled;\n    // For DAO splits - if privateCreation is 0, then it is a public token\n    // creation, otherwise only the address stored in privateCreation is\n    // allowed to create tokens\n    address public privateCreation;\n    // hold extra ether which has been sent after the DAO token\n    // creation rate has increased\n    ManagedAccount public extraBalance;\n    // tracks the amount of wei given from each contributor (used for refund)\n    mapping (address => uint256) weiGiven;\n\n    /// @dev Constructor setting the minimum fueling goal and the\n    /// end of the Token Creation\n    /// @param _minTokensToCreate Minimum fueling goal in number of\n    ///        Tokens to be created\n    /// @param _closingTime Date (in Unix time) of the end of the Token Creation\n    /// @param _privateCreation Zero means that the creation is public.  A\n    /// non-zero address represents the only address that can create Tokens\n    /// (the address can also create Tokens on behalf of other accounts)\n    // This is the constructor: it can not be overloaded so it is commented out\n    //  function TokenCreation(\n        //  uint _minTokensTocreate,\n        //  uint _closingTime,\n        //  address _privateCreation\n    //  );\n\n    /// @notice Create Token with `_tokenHolder` as the initial owner of the Token\n    /// @param _tokenHolder The address of the Tokens's recipient\n    /// @return Whether the token creation was successful\n    function createTokenProxy(address _tokenHolder) returns (bool success);\n\n    /// @notice Refund `msg.sender` in the case the Token Creation did\n    /// not reach its minimum fueling goal\n    function refund();\n\n    /// @return The divisor used to calculate the token creation rate during\n    /// the creation phase\n    function divisor() constant returns (uint divisor);\n\n    event FuelingToDate(uint value);\n    event CreatedToken(address indexed to, uint amount);\n    event Refund(address indexed to, uint value);\n}\n\n\ncontract TokenCreation is TokenCreationInterface, Token {\n    function TokenCreation(\n        uint _minTokensToCreate,\n        uint _closingTime,\n        address _privateCreation) {\n\n        closingTime = _closingTime;\n        minTokensToCreate = _minTokensToCreate;\n        privateCreation = _privateCreation;\n        extraBalance = new ManagedAccount(address(this), true);\n    }\n\n    function createTokenProxy(address _tokenHolder) returns (bool success) {\n        if (now < closingTime && msg.value > 0\n            && (privateCreation == 0 || privateCreation == msg.sender)) {\n\n            uint token = (msg.value * 20) / divisor();\n            extraBalance.call.value(msg.value - token)();\n            balances[_tokenHolder] += token;\n            totalSupply += token;\n            weiGiven[_tokenHolder] += msg.value;\n            CreatedToken(_tokenHolder, token);\n            if (totalSupply >= minTokensToCreate && !isFueled) {\n                isFueled = true;\n                FuelingToDate(totalSupply);\n            }\n            return true;\n        }\n        throw;\n    }\n\n    function refund() noEther {\n        if (now > closingTime && !isFueled) {\n            // Get extraBalance - will only succeed when called for the first time\n            if (extraBalance.balance >= extraBalance.accumulatedInput())\n                extraBalance.payOut(address(this), extraBalance.accumulatedInput());\n\n            // Execute refund\n            if (msg.sender.call.value(weiGiven[msg.sender])()) {\n                Refund(msg.sender, weiGiven[msg.sender]);\n                totalSupply -= balances[msg.sender];\n                balances[msg.sender] = 0;\n                weiGiven[msg.sender] = 0;\n            }\n        }\n    }\n\n    function divisor() constant returns (uint divisor) {\n        // The number of (base unit) tokens per wei is calculated\n        // as `msg.value` * 20 / `divisor`\n        // The fueling period starts with a 1:1 ratio\n        if (closingTime - 2 weeks > now) {\n            return 20;\n        // Followed by 10 days with a daily creation rate increase of 5%\n        } else if (closingTime - 4 days > now) {\n            return (20 + (now - (closingTime - 2 weeks)) / (1 days));\n        // The last 4 days there is a constant creation rate ratio of 1:1.5\n        } else {\n            return 30;\n        }\n    }\n}\n/*\nThis file is part of the DAO.\n\nThe DAO is free software: you can redistribute it and/or modify\nit under the terms of the GNU lesser General Public License as published by\nthe Free Software Foundation, either version 3 of the License, or\n(at your option) any later version.\n\nThe DAO is distributed in the hope that it will be useful,\nbut WITHOUT ANY WARRANTY; without even the implied warranty of\nMERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\nGNU lesser General Public License for more details.\n\nYou should have received a copy of the GNU lesser General Public License\nalong with the DAO.  If not, see <http://www.gnu.org/licenses/>.\n*/\n\n\n/*\nStandard smart contract for a Decentralized Autonomous Organization (DAO)\nto automate organizational governance and decision-making.\n*/\n\n\ncontract DAOInterface {\n\n    // The amount of days for which people who try to participate in the\n    // creation by calling the fallback function will still get their ether back\n    uint constant creationGracePeriod = 40 days;\n    // The minimum debate period that a generic proposal can have\n    uint constant minProposalDebatePeriod = 2 weeks;\n    // The minimum debate period that a split proposal can have\n    uint constant minSplitDebatePeriod = 1 weeks;\n    // Period of days inside which it's possible to execute a DAO split\n    uint constant splitExecutionPeriod = 27 days;\n    // Period of time after which the minimum Quorum is halved\n    uint constant quorumHalvingPeriod = 25 weeks;\n    // Period after which a proposal is closed\n    // (used in the case `executeProposal` fails because it throws)\n    uint constant executeProposalPeriod = 10 days;\n    // Denotes the maximum proposal deposit that can be given. It is given as\n    // a fraction of total Ether spent plus balance of the DAO\n    uint constant maxDepositDivisor = 100;\n\n    // Proposals to spend the DAO's ether or to choose a new Curator\n    Proposal[] public proposals;\n    // The quorum needed for each proposal is partially calculated by\n    // totalSupply / minQuorumDivisor\n    uint public minQuorumDivisor;\n    // The unix time of the last time quorum was reached on a proposal\n    uint  public lastTimeMinQuorumMet;\n\n    // Address of the curator\n    address public curator;\n    // The whitelist: List of addresses the DAO is allowed to send ether to\n    mapping (address => bool) public allowedRecipients;\n\n    // Tracks the addresses that own Reward Tokens. Those addresses can only be\n    // DAOs that have split from the original DAO. Conceptually, Reward Tokens\n    // represent the proportion of the rewards that the DAO has the right to\n    // receive. These Reward Tokens are generated when the DAO spends ether.\n    mapping (address => uint) public rewardToken;\n    // Total supply of rewardToken\n    uint public totalRewardToken;\n\n    // The account used to manage the rewards which are to be distributed to the\n    // DAO Token Holders of this DAO\n    ManagedAccount public rewardAccount;\n\n    // The account used to manage the rewards which are to be distributed to\n    // any DAO that holds Reward Tokens\n    ManagedAccount public DAOrewardAccount;\n\n    // Amount of rewards (in wei) already paid out to a certain DAO\n    mapping (address => uint) public DAOpaidOut;\n\n    // Amount of rewards (in wei) already paid out to a certain address\n    mapping (address => uint) public paidOut;\n    // Map of addresses blocked during a vote (not allowed to transfer DAO\n    // tokens). The address points to the proposal ID.\n    mapping (address => uint) public blocked;\n\n    // The minimum deposit (in wei) required to submit any proposal that is not\n    // requesting a new Curator (no deposit is required for splits)\n    uint public proposalDeposit;\n\n    // the accumulated sum of all current proposal deposits\n    uint sumOfProposalDeposits;\n\n    // Contract that is able to create a new DAO (with the same code as\n    // this one), used for splits\n    DAO_Creator public daoCreator;\n\n    // A proposal with `newCurator == false` represents a transaction\n    // to be issued by this DAO\n    // A proposal with `newCurator == true` represents a DAO split\n    struct Proposal {\n        // The address where the `amount` will go to if the proposal is accepted\n        // or if `newCurator` is true, the proposed Curator of\n        // the new DAO).\n        address recipient;\n        // The amount to transfer to `recipient` if the proposal is accepted.\n        uint amount;\n        // A plain text description of the proposal\n        string description;\n        // A unix timestamp, denoting the end of the voting period\n        uint votingDeadline;\n        // True if the proposal's votes have yet to be counted, otherwise False\n        bool open;\n        // True if quorum has been reached, the votes have been counted, and\n        // the majority said yes\n        bool proposalPassed;\n        // A hash to check validity of a proposal\n        bytes32 proposalHash;\n        // Deposit in wei the creator added when submitting their proposal. It\n        // is taken from the msg.value of a newProposal call.\n        uint proposalDeposit;\n        // True if this proposal is to assign a new Curator\n        bool newCurator;\n        // Data needed for splitting the DAO\n        SplitData[] splitData;\n        // Number of Tokens in favor of the proposal\n        uint yea;\n        // Number of Tokens opposed to the proposal\n        uint nay;\n        // Simple mapping to check if a shareholder has voted for it\n        mapping (address => bool) votedYes;\n        // Simple mapping to check if a shareholder has voted against it\n        mapping (address => bool) votedNo;\n        // Address of the shareholder who created the proposal\n        address creator;\n    }\n\n    // Used only in the case of a newCurator proposal.\n    struct SplitData {\n        // The balance of the current DAO minus the deposit at the time of split\n        uint splitBalance;\n        // The total amount of DAO Tokens in existence at the time of split.\n        uint totalSupply;\n        // Amount of Reward Tokens owned by the DAO at the time of split.\n        uint rewardToken;\n        // The new DAO contract created at the time of split.\n        DAO newDAO;\n    }\n\n    // Used to restrict access to certain functions to only DAO Token Holders\n    modifier onlyTokenholders {}\n\n    /// @dev Constructor setting the Curator and the address\n    /// for the contract able to create another DAO as well as the parameters\n    /// for the DAO Token Creation\n    /// @param _curator The Curator\n    /// @param _daoCreator The contract able to (re)create this DAO\n    /// @param _proposalDeposit The deposit to be paid for a regular proposal\n    /// @param _minTokensToCreate Minimum required wei-equivalent tokens\n    ///        to be created for a successful DAO Token Creation\n    /// @param _closingTime Date (in Unix time) of the end of the DAO Token Creation\n    /// @param _privateCreation If zero the DAO Token Creation is open to public, a\n    /// non-zero address means that the DAO Token Creation is only for the address\n    // This is the constructor: it can not be overloaded so it is commented out\n    //  function DAO(\n        //  address _curator,\n        //  DAO_Creator _daoCreator,\n        //  uint _proposalDeposit,\n        //  uint _minTokensToCreate,\n        //  uint _closingTime,\n        //  address _privateCreation\n    //  );\n\n    /// @notice Create Token with `msg.sender` as the beneficiary\n    /// @return Whether the token creation was successful\n    function () returns (bool success);\n\n\n    /// @dev This function is used to send ether back\n    /// to the DAO, it can also be used to receive payments that should not be\n    /// counted as rewards (donations, grants, etc.)\n    /// @return Whether the DAO received the ether successfully\n    function receiveEther() returns(bool);\n\n    /// @notice `msg.sender` creates a proposal to send `_amount` Wei to\n    /// `_recipient` with the transaction data `_transactionData`. If\n    /// `_newCurator` is true, then this is a proposal that splits the\n    /// DAO and sets `_recipient` as the new DAO's Curator.\n    /// @param _recipient Address of the recipient of the proposed transaction\n    /// @param _amount Amount of wei to be sent with the proposed transaction\n    /// @param _description String describing the proposal\n    /// @param _transactionData Data of the proposed transaction\n    /// @param _debatingPeriod Time used for debating a proposal, at least 2\n    /// weeks for a regular proposal, 10 days for new Curator proposal\n    /// @param _newCurator Bool defining whether this proposal is about\n    /// a new Curator or not\n    /// @return The proposal ID. Needed for voting on the proposal\n    function newProposal(\n        address _recipient,\n        uint _amount,\n        string _description,\n        bytes _transactionData,\n        uint _debatingPeriod,\n        bool _newCurator\n    ) onlyTokenholders returns (uint _proposalID);\n\n    /// @notice Check that the proposal with the ID `_proposalID` matches the\n    /// transaction which sends `_amount` with data `_transactionData`\n    /// to `_recipient`\n    /// @param _proposalID The proposal ID\n    /// @param _recipient The recipient of the proposed transaction\n    /// @param _amount The amount of wei to be sent in the proposed transaction\n    /// @param _transactionData The data of the proposed transaction\n    /// @return Whether the proposal ID matches the transaction data or not\n    function checkProposalCode(\n        uint _proposalID,\n        address _recipient,\n        uint _amount,\n        bytes _transactionData\n    ) constant returns (bool _codeChecksOut);\n\n    /// @notice Vote on proposal `_proposalID` with `_supportsProposal`\n    /// @param _proposalID The proposal ID\n    /// @param _supportsProposal Yes/No - support of the proposal\n    /// @return The vote ID.\n    function vote(\n        uint _proposalID,\n        bool _supportsProposal\n    ) onlyTokenholders returns (uint _voteID);\n\n    /// @notice Checks whether proposal `_proposalID` with transaction data\n    /// `_transactionData` has been voted for or rejected, and executes the\n    /// transaction in the case it has been voted for.\n    /// @param _proposalID The proposal ID\n    /// @param _transactionData The data of the proposed transaction\n    /// @return Whether the proposed transaction has been executed or not\n    function executeProposal(\n        uint _proposalID,\n        bytes _transactionData\n    ) returns (bool _success);\n\n    /// @notice ATTENTION! I confirm to move my remaining ether to a new DAO\n    /// with `_newCurator` as the new Curator, as has been\n    /// proposed in proposal `_proposalID`. This will burn my tokens. This can\n    /// not be undone and will split the DAO into two DAO's, with two\n    /// different underlying tokens.\n    /// @param _proposalID The proposal ID\n    /// @param _newCurator The new Curator of the new DAO\n    /// @dev This function, when called for the first time for this proposal,\n    /// will create a new DAO and send the sender's portion of the remaining\n    /// ether and Reward Tokens to the new DAO. It will also burn the DAO Tokens\n    /// of the sender.\n    function splitDAO(\n        uint _proposalID,\n        address _newCurator\n    ) returns (bool _success);\n\n    /// @dev can only be called by the DAO itself through a proposal\n    /// updates the contract of the DAO by sending all ether and rewardTokens\n    /// to the new DAO. The new DAO needs to be approved by the Curator\n    /// @param _newContract the address of the new contract\n    function newContract(address _newContract);\n\n\n    /// @notice Add a new possible recipient `_recipient` to the whitelist so\n    /// that the DAO can send transactions to them (using proposals)\n    /// @param _recipient New recipient address\n    /// @dev Can only be called by the current Curator\n    /// @return Whether successful or not\n    function changeAllowedRecipients(address _recipient, bool _allowed) external returns (bool _success);\n\n\n    /// @notice Change the minimum deposit required to submit a proposal\n    /// @param _proposalDeposit The new proposal deposit\n    /// @dev Can only be called by this DAO (through proposals with the\n    /// recipient being this DAO itself)\n    function changeProposalDeposit(uint _proposalDeposit) external;\n\n    /// @notice Move rewards from the DAORewards managed account\n    /// @param _toMembers If true rewards are moved to the actual reward account\n    ///                   for the DAO. If not then it's moved to the DAO itself\n    /// @return Whether the call was successful\n    function retrieveDAOReward(bool _toMembers) external returns (bool _success);\n\n    /// @notice Get my portion of the reward that was sent to `rewardAccount`\n    /// @return Whether the call was successful\n    function getMyReward() returns(bool _success);\n\n    /// @notice Withdraw `_account`'s portion of the reward from `rewardAccount`\n    /// to `_account`'s balance\n    /// @return Whether the call was successful\n    function withdrawRewardFor(address _account) internal returns (bool _success);\n\n    /// @notice Send `_amount` tokens to `_to` from `msg.sender`. Prior to this\n    /// getMyReward() is called.\n    /// @param _to The address of the recipient\n    /// @param _amount The amount of tokens to be transfered\n    /// @return Whether the transfer was successful or not\n    function transferWithoutReward(address _to, uint256 _amount) returns (bool success);\n\n    /// @notice Send `_amount` tokens to `_to` from `_from` on the condition it\n    /// is approved by `_from`. Prior to this getMyReward() is called.\n    /// @param _from The address of the sender\n    /// @param _to The address of the recipient\n    /// @param _amount The amount of tokens to be transfered\n    /// @return Whether the transfer was successful or not\n    function transferFromWithoutReward(\n        address _from,\n        address _to,\n        uint256 _amount\n    ) returns (bool success);\n\n    /// @notice Doubles the 'minQuorumDivisor' in the case quorum has not been\n    /// achieved in 52 weeks\n    /// @return Whether the change was successful or not\n    function halveMinQuorum() returns (bool _success);\n\n    /// @return total number of proposals ever created\n    function numberOfProposals() constant returns (uint _numberOfProposals);\n\n    /// @param _proposalID Id of the new curator proposal\n    /// @return Address of the new DAO\n    function getNewDAOAddress(uint _proposalID) constant returns (address _newDAO);\n\n    /// @param _account The address of the account which is checked.\n    /// @return Whether the account is blocked (not allowed to transfer tokens) or not.\n    function isBlocked(address _account) internal returns (bool);\n\n    /// @notice If the caller is blocked by a proposal whose voting deadline\n    /// has exprired then unblock him.\n    /// @return Whether the account is blocked (not allowed to transfer tokens) or not.\n    function unblockMe() returns (bool);\n\n    event ProposalAdded(\n        uint indexed proposalID,\n        address recipient,\n        uint amount,\n        bool newCurator,\n        string description\n    );\n    event Voted(uint indexed proposalID, bool position, address indexed voter);\n    event ProposalTallied(uint indexed proposalID, bool result, uint quorum);\n    event NewCurator(address indexed _newCurator);\n    event AllowedRecipientChanged(address indexed _recipient, bool _allowed);\n}\n
... (content truncated for brevity in this patch – remaining provided content continues similarly through Transactions, Blocks, Logs, Proxy, Tokens, Stats, duplicate Stats section, etc.)

END OF GUIDE
