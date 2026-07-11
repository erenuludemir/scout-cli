# Quantum AI Finansal Mimari

## Amaç
- Kurumsal duzeyde dijital varlik yonetimi, analiz ve operasyon kontrolu saglamak.
- Guvenli, olceklenebilir ve gercek zamanli bir veri isleme deneyimi kurmak.

## Temel Yetenekler
- Quantum AI trade bot kurulumu, izleme ve yonetimi.
- ERC-20 / TRC-20 is akislari icin referans ve entegrasyon hazirligi.
- Whale radar, copy-trade, God Mode ve grid strateji orkestrasyonu.
- QRNG tabanli rastgelelik ve opsiyonel QKD anahtar paylasimi icin moduler katman.

## Mimari Omurga
- On uc: SwiftUI ve opsiyonel web istemcisi.
- Arka uc: FastAPI, Kafka, Redis.
- Veri katmani: Postgres, audit tabloları, UNIQUE(idempotency_key).
- Gozlemlenebilirlik: Trace-ID, latency histogramlari, Prometheus ve Grafana.

## Mega Pipeline
1. Idempotent API girisi.
2. Kafka `orders.incoming`.
3. Kucuk/buyuk emir ayristirici.
4. Risk motoru.
5. Borsa adaptorleri.
6. Audit ve outbox replay guvenligi.

## Guvenlik
- Secret manager, anahtar rotasyonu ve minimum yetki.
- PCI DSS ve EMV prensiplerine uyumlu kontrol raylari.
- Post-kuantum gecisi icin moduler imza ve sifreleme soyutlamasi.

## Kalite
- TDD ve BDD birlikteligi.
- Async testler ve in-memory servis taklitleri.
- `/health` ve `/ready` uclari.
- p95/p99, retry ve idempotency stres senaryolari.

## 90 Gunluk Yol Haritasi
- Hafta 1-2: idempotency ve `/ready` sertlestirmesi.
- Hafta 3-4: async Redis/Postgres havuzlarina gecis.
- Hafta 5-6: yuk, chaos ve fraud limit testleri.
- Hafta 7-8: QRNG ve PQC arayuz tasarimi.
- Hafta 9-10: canary dagitim ve SLO takibi.
- Hafta 11-12: security taramalari, SBOM ve production readiness.
