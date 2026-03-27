# Operasyon Runbook
## Kuyruk sıkışması
- Queue depth kontrol et
- Pending order'ları tekrar sırala
- Duplicate key olanları drop et
## Duplicate emir
- idempotencyKey kontrol
- aynı key varsa ACK + DROP
## Anahtar hatası
- Biyometri doğrula
- Keychain erişim test et
## Upgrade
- feature flag ile aç
- lightweight migration
## Rollback
- Live kapat
- yeni yazmaları kilitle
- okuma devam
