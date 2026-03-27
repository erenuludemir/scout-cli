# Quantum AI iOS Mega Boru Hattı

Bu paket Swift Package tabanlı gömülü iOS istemci iskeletidir.

## Hedef
- Offline-first
- Sim Mode anında çalışır
- Live Mode için idempotent eşitleme altyapısı içerir
- 0 third-party

## Açılış
1. Xcode -> Open Package -> bu klasörü aç
2. iOS App target oluştur veya mevcut app target içine `QuantumAIMobile` package'ını ekle
3. `QuantumAIMobileApp.swift` dosyasını App target'a kopyala ya da aynı içerikle kullan
4. `FeatureFlags.plist` dosyasını bundle'a dahil et
5. Sim Mode ile başlat

## Modüller
- AppShell
- DesignSystem
- WalletKit
- SecurityKit
- MarketKit
- BotKit
- AlertKit
- StorageKit
- ObservabilityKit
- SettingsKit

## Operasyon
- Runbook: `QuantumAIMobile/Runbook/OPERATIONS_RUNBOOK.md`
- Kılavuzlar: `QuantumAIMobile/Resources/`
