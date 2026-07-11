# QuantumAIMobile Repo Onarım Denetim Listesi

## 1. /Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/_reports/repair_runbook/20260401_172758/02_package_scope.txt

### Kontrol checklist
- `Package.swift` içindeki `exclude` listesinde `.bak`, `.orig`, `.tmp`, `.disabled` türevleri açık path olarak var mı
- `sources` altında sadece gerçek üretim klasörleri mi var
- `resources` altında sadece `Resources` mı var
- `DesignSystem/PerformanceChart.swift`
- `StorageKit/AuditReportGenerator.swift`
- `StorageKit/IntegrityChecker.swift`
- `SyncKit/SyncClient.legacy.disabled`
- `SyncKit/SyncClient.legacy.disabled.SyncKit`
- `AppShell/RootView.swift.bak.20260330_132611`
- `AppShell/RootView.swift.bak`
- `AppShell/RootView.swift.orig`
- `AppShell/RootView.swift.tmp`

### Doğruysa ne görmelisin
- `exclude` içinde yukarıdaki scope dışı dosyalar açıkça yer alır
- `sources` listesi yalnız:
  - `AlertKit`
  - `AppShell`
  - `BotKit`
  - `CoreKit`
  - `DesignSystem`
  - `MarketKit`
  - `NetworkKit`
  - `ObservabilityKit`
  - `PropertyKit`
  - `SecurityKit`
  - `SettingsKit`
  - `StorageKit`
  - `Support`
  - `SyncKit`
  - `WalletKit`
- `resources` yalnız `.process("Resources")`

### Yanlışsa hangi satırı düzeltmelisin
- `ios/QuantumAIMobile/Package.swift` içindeki `.target(name: "QuantumAIMobile", ...)` bloğundaki `exclude:` satırları
- `sources:` satırları
- `resources:` satırları

---

## 2. /Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/_reports/repair_runbook/20260401_172758/03_xcodeproj_refs.txt

### Kontrol checklist
- `.bak`
- `.orig`
- `.tmp`
- `.disabled`
- `legacy`
- `snapshot`
- `log`
- aynı `.swift` dosyasının birden fazla referansı
- `Copy Bundle Resources` içine düşmüş destek dosyaları
- `Compile Sources` içine düşmüş üretim dışı dosyalar

### Doğruysa ne görmelisin
- yalnız gerçek üretim `.swift` dosyaları target referansı taşır
- backup veya meta dosyaları target member değildir
- `Copy Bundle Resources` içinde geliştirme dosyası yoktur
- aynı kaynak dosyanın duplicate proje referansı yoktur

### Yanlışsa hangi satırı düzeltmelisin
- `ios/QuantumAIMobileHost.xcodeproj/project.pbxproj`
- `ios/QuantumAIMobileApp/QuantumAIMobileApp.xcodeproj/project.pbxproj`
- ilgili `PBXSourcesBuildPhase`
- ilgili `PBXResourcesBuildPhase`
- ilgili `PBXBuildFile`
- ilgili `PBXFileReference`

---

## 3. /Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/_reports/repair_runbook/20260401_172758/05_wallet_duplicate_scan.txt

### Kontrol checklist
- `RawTransaction`
- `signTRON`
- aynı init imzası
- aynı extension zinciri
- signer ile model aynı dosyada mı dağılmış
- aynı sembol ikinci dosyada tekrar ediyor mu

### Doğruysa ne görmelisin
- `RawTransaction` tek owner
- `signTRON(txHash:)` tek owner
- `WalletService` tek signer surface kullanır
- `WalletView` canonical initializer kullanır

### Yanlışsa hangi satırı düzeltmelisin
- `ios/QuantumAIMobile/QuantumAIMobile/WalletKit/TransactionSigner.swift`
- `ios/QuantumAIMobile/QuantumAIMobile/WalletKit/WalletService.swift`
- `ios/QuantumAIMobile/QuantumAIMobile/AppShell/WalletView.swift`

---

## 4. /Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/_reports/repair_runbook/20260401_172758/06_owner_surface_scan.txt

### Kontrol checklist
- `watchlist`
- `outbox`
- `appendAudit`
- `append`
- `flushOutbox`
- `queueForBroadcast`

### Doğruysa ne görmelisin
- `AppEnvironment` state owner çizgisi net
- `StorageService` storage/audit/outbox owner çizgisi net
- `SyncClient` yalnız sync owner
- UI dosyaları tek canonical surface tüketiyor

### Yanlışsa hangi satırı düzeltmelisin
- `ios/QuantumAIMobile/QuantumAIMobile/AppShell/AppEnvironment.swift`
- `ios/QuantumAIMobile/QuantumAIMobile/StorageKit/StorageService.swift`
- `ios/QuantumAIMobile/QuantumAIMobile/StorageKit/AuditService.swift`
- `ios/QuantumAIMobile/QuantumAIMobile/SyncKit/SyncClient.swift`
- `ios/QuantumAIMobile/QuantumAIMobile/SyncKit/RemoteMonitor.swift`

---

## 5. /Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/_reports/repair_runbook/20260401_172758/11_next_actions.txt

### Kontrol checklist
- ilk faz gerçekten build surface temizliği ile başlıyor mu
- Wallet duplicate çözümü scope temizliğinden sonra mı geliyor
- owner surface sabitleme Wallet sonrası mı geliyor
- UI katmanı servis sözleşmesinden sonra mı geliyor
- signing en sonda mı

### Doğruysa ne görmelisin
- sıra şu olmalı:
  1. build kapsamı
  2. WalletKit tekilleştirme
  3. owner surface sabitleme
  4. UI/adapter uyarlama
  5. code build
  6. signing/device/archive

### Yanlışsa hangi satırı düzeltmelisin
- `/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/ops/repair_runbook/run_quantumai_repo_triage.sh` içinde `11_next_actions.txt` üreten echo sırası
