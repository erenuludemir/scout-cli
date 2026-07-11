# QuantumAIMobile Repair Decision Tree

## 1
Eğer ilk generic/simulator build'de `multiple producers` varsa:
- Faz 1'e dön
- Önce `Package.swift`
- Sonra `project.pbxproj`
- Sonra duplicate fiziksel dosya taraması

## 2
Eğer `RawTransaction` veya `signTRON(txHash:)` kalıyorsa:
- Faz 2'ye dön
- `TransactionSigner.swift`
- `WalletService.swift`
- `WalletView.swift`

## 3
Eğer `watchlist/outbox/appendAudit/flushOutbox/queueForBroadcast` kalıyorsa:
- Faz 3'e dön
- `AppEnvironment.swift`
- `StorageService.swift`
- `AuditService.swift`
- `SyncClient.swift`
- `RemoteMonitor.swift`

## 4
Eğer `$outbox`, `append`, `marketBuy`, `marketCopy` kalıyorsa:
- Faz 4'e dön
- `HealthPanelModel.swift`
- `BotService.swift`
- `CopyTradeService.swift`

## 5
Eğer `LoginView`, `SummaryStatCard`, `TerminalStatCard`, `PerformanceChart`, `sampleData`, `BinanceAdapter` kalıyorsa:
- Faz 5'e dön
- UI/adaptor fiziksel varlık ve target kapsamını doğrula
- Sonra yalnız tüketici çağrılarını düzelt

## 6
Eğer yalnız device/profile hatası kaldıysa:
- Faz 7'ye geç
- Kod triage bitti
- Signing/devices/profiles çalış
