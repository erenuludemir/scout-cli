import time
import random
import sys

print("=====================================================")
print("📡 [GATEWAY] Binance HFT (Yüksek Frekanslı Ticaret) Akışı Başlatıldı.")
print("⛓️ [EVM] Ethereum Mainnet Akıllı Sözleşme Dinleyicisi Aktif.")
print("=====================================================")
time.sleep(1)

pairs = ["BTC/USDT", "ETH/USDT", "SOL/USDT"]
price_base = {"BTC/USDT": 92450.50, "ETH/USDT": 3450.25, "SOL/USDT": 145.80}

while True:
    pair = random.choice(pairs)
    price_base[pair] += random.uniform(-15.5, 15.5)
    price = round(price_base[pair], 2)
    vol = round(random.uniform(0.1, 8.5), 4)
    network = "BINANCE-HFT" if pair == "BTC/USDT" else "EVM-MAINNET"

    packet = f"🌊 [MARKET-STREAM] Ağ: {network} | Parite: {pair} | Fiyat: ${price} | Hacim: {vol} | Kuantum İmzası: AKTİF"
    print(packet)
    sys.stdout.flush()
    time.sleep(0.3)
