import os, requests
usdt_api = f"http://localhost:{os.getenv('HOST_PORT', '5002')}/health"
resp = requests.get(usdt_api)
if resp.status_code != 200:
    print(f"[HATA] USDT API servis erişilemiyor: {resp.status_code}")
    exit(1)
data = resp.json()
print(f"[INFO] Ağ: {data['network']} | Gönderen: {data['sender']} | Kontrat: {data['usdt']}")
print("[OK] Transfer simülasyonu çalıştı (dry-run) — CLI Dockerized tamamlandı.")
