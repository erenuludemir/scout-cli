// send-usdt.js
import { ethers } from "ethers";

const RPC_URL = process.env.RPC_URL_MAINNET;
const PK      = process.env.SENDER_PRIVATE_KEY;

const TOKEN   = "0xdAC17F958D2ee523a2206206994597C13D831ec7"; // USDT
const TO      = "0x63E2E2031AfeD4f10d5510E25cdB5976E67FE466";

const abi = [
  "function decimals() view returns (uint8)",
  "function balanceOf(address) view returns (uint256)",
  "function transfer(address,uint256) returns (bool)"
];

(async () => {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet   = new ethers.Wallet(PK, provider);
  const usdt     = new ethers.Contract(TOKEN, abi, wallet);

  const dec         = await usdt.decimals();      // USDT -> 6
  const amount      = ethers.parseUnits("100000", dec); // 100,000 USDT
  const ethBalance  = await provider.getBalance(wallet.address);
  if (ethBalance === 0n) throw new Error("Gönderici adreste gaz için ETH yok.");

  // (İsteğe bağlı) dry-run
  await usdt.transfer.staticCall(TO, amount);

  const tx = await usdt.transfer(TO, amount);
  console.log("tx hash:", tx.hash);
  const rcpt = await tx.wait();
  console.log("mined:", rcpt.hash);
})();
