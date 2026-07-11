# QuantumAIMobile Repo Repair File Checklist

## Faz 1 — Build kapsamını temizle

### 1. ios/QuantumAIMobile/Package.swift
#### Kontrol checklist
- [ ] `targets` içinde `path`, `sources`, `resources`, `exclude` açık ve okunabilir mi
- [ ] `.bak`, `.orig`, `.tmp`, `.disabled`, `.legacy`, `.sample` varyantları `exclude` içinde mi
- [ ] `sources` yalnız gerçek üretim klasörlerini mi içeriyor
- [ ] `resources` içine yanlışlıkla `.swift`, `.bak`, `.log`, `.md`, `.plist` test/support dosyaları girmiş mi
- [ ] `PerformanceChart.swift` gibi şu an kullanılmayan ama exclude edilmiş görünen dosyalar ile gerçek UI bağımlılıkları çakışıyor mu

#### Beklenen doğru durum
- `exclude` içinde tüm backup/geçici/legacy dosya aileleri bulunur
- `sources` yalnız canlı kaynak klasörlerini kapsar
- `resources` yalnız bundle'a girmesi gereken gerçek asset/resource dosyalarını içerir
- `RootView.swift.bak.20260330_132611` benzeri dosyalar target kapsamı dışında kalır

#### Bulgu → düzeltme
- `exclude` dar ise genişlet
- `resources` kirliyse temizle
- `sources` çok genişse daralt
- Aynı dosya hem package hem xcodeproj ile iki kez alınıyorsa tek kaynağa indir

### 2. ios/QuantumAIMobileHost.xcodeproj ve ios/QuantumAIMobileApp/*.xcodeproj
#### Kontrol checklist
- [ ] `project.pbxproj` içinde `.bak`, `.orig`, `.tmp`, `.disabled`, `.legacy` referansı var mı
- [ ] `PBXSourcesBuildPhase` içine yanlış dosya girmiş mi
- [ ] `PBXResourcesBuildPhase` içine yanlış dosya girmiş mi
- [ ] `RootView.swift.bak.20260330_132611` veya benzeri dosyalar target üyesi mi
- [ ] Aynı fiziksel dosya birden fazla target phase içinde mi

#### Beklenen doğru durum
- Compile Sources içinde yalnız gerçek `.swift` üretim dosyaları kalır
- Copy Bundle Resources içinde yalnız gerçek resource dosyaları kalır
- Backup/snapshot/log türleri projede referans olarak bile bulunmaz ya da en azından target dışıdır

#### Bulgu → düzeltme
- Yanlış phase üyeliği varsa kaldır
- Aynı dosya birden çok kez görünüyorsa tekilleştir
- Projeden silmeden target dışına çıkar

### 3. Repo geneli dosya taraması
#### Kontrol checklist
- [ ] `*.bak*`, `*.orig*`, `*.tmp*`, `*.disabled*`, `*.legacy*` dosyaları nerelerde
- [ ] Aynı tip/model/fonksiyon başka dosyalarda da var mı
- [ ] `RawTransaction`, `signTRON`, `watchlist`, `outbox`, `appendAudit`, `flushOutbox`, `queueForBroadcast` birden çok yerde mi tanımlı

#### Beklenen doğru durum
- Şüpheli backup/geçici dosyalar kaynak ağacında olsa bile build kapsamına girmemeli
- Ortak tip ve ortak API’lerin sahibi tek olmalı

#### Bulgu → düzeltme
- Fiziksel dosyayı silmeden kapsam dışına al
- Duplicate type/function owner belirle

## Faz 2 — WalletKit tekilleştirme

### 4. ios/QuantumAIMobile/QuantumAIMobile/WalletKit/TransactionSigner.swift
#### Kontrol checklist
- [ ] `struct/class/enum RawTransaction` burada mı
- [ ] `signTRON(txHash:)` burada mı
- [ ] Aynı isimli ikinci tanım bu dosyada var mı
- [ ] `append` çağrıları gerçekten veri buffer nesnesine mi gidiyor
- [ ] Yerel değişken isimleri fonksiyon/closure isimleriyle çakışıyor mu

#### Beklenen doğru durum
- `RawTransaction` tek canonical tanıma sahip
- `signTRON(txHash:)` tek canonical implementasyona sahip
- `append` yalnız gerçek mutable veri taşıyıcıya çağrılır

#### Bulgu → düzeltme
- Duplicate model/fonksiyon tanımını tek dosyaya indir
- Gölgeleme yapan yerel isimleri yeniden adlandır
- Sign flow'u modelden ayır ama ownership'i tekilleştir

### 5. ios/QuantumAIMobile/QuantumAIMobile/WalletKit/WalletService.swift
#### Kontrol checklist
- [ ] `RawTransaction` referansı hangi dosyadan geliyor
- [ ] Signer çağrısı hangi public API'ye bağlı
- [ ] `queueForBroadcast` burada mı başka serviste mi

#### Beklenen doğru durum
- WalletService yalnız tek signer/model yüzeyini kullanır
- Broadcast sırası ve owner nettir

#### Bulgu → düzeltme
- Eski signer API çağrılarını canonical signer API'ye taşı
- `queueForBroadcast` sahibi sabitlenir

### 6. ios/QuantumAIMobile/QuantumAIMobile/AppShell/WalletView.swift
#### Kontrol checklist
- [ ] `RawTransaction` doğrudan view içinde mi üretiliyor
- [ ] `init(chainId:nonce:to:value:data:)` birden fazla aday mı görüyor
- [ ] WalletService yerine view kendi modelini mi kuruyor

#### Beklenen doğru durum
- View katmanı tek canonical init/factory kullanır
- İmza ve broadcast mantığı servis katmanına aittir

#### Bulgu → düzeltme
- View tarafındaki model üretimini azalt
- Gerekirse factory veya WalletService üstünden model kur

## Faz 3 — Ortak servis sözleşmesini sabitle

### 7. ios/QuantumAIMobile/QuantumAIMobile/AppShell/AppEnvironment.swift
#### Kontrol checklist
- [ ] `watchlist` burada mı
- [ ] `storage` burada mı
- [ ] `syncClient` burada mı
- [ ] init imzaları tüm tüketicilerle uyumlu mu

#### Beklenen doğru durum
- AppEnvironment ortak owner registry gibi davranır
- Ortak state ve servis referansları tek surface üstünden paylaşılır

#### Bulgu → düzeltme
- `watchlist/storage/syncClient` owner'larını burada netleştir
- Eski init imzalarını tek canonical init’e indir

### 8. ios/QuantumAIMobile/QuantumAIMobile/StorageKit/StorageService.swift
#### Kontrol checklist
- [ ] `outbox` burada mı
- [ ] `$outbox` publisher yüzeyi burada mı
- [ ] `append`, `appendAudit`, `queueForBroadcast` burada mı
- [ ] `AuditReportGenerator` referansı canlı mı

#### Beklenen doğru durum
- StorageService ortak veri yüzeyinin sahibi olur
- Tüm public property/method isimleri sabittir

#### Bulgu → düzeltme
- Public API yüzeyi burada yazılı olarak sabitlenir
- Tüketiciler bu yüzeye taşınır

### 9. ios/QuantumAIMobile/QuantumAIMobile/StorageKit/AuditService.swift
#### Kontrol checklist
- [ ] `appendAudit` doğru servise mi çağrılıyor
- [ ] `SHA256` kullanımı hedef platformla uyumlu mu
- [ ] Audit akışı StorageService sözleşmesine uyuyor mu

#### Beklenen doğru durum
- AuditService yalnız audit üretir
- Yazma/kalıcılık owner’ı StorageService olur

#### Bulgu → düzeltme
- Audit output’u canonical appendAudit hattına bağla
- Hâlâ deployment hatası varsa önce target/platform çözümlemesini doğrula

### 10. ios/QuantumAIMobile/QuantumAIMobile/SyncKit/SyncClient.swift
#### Kontrol checklist
- [ ] `flushOutbox` burada mı
- [ ] Dosya package ve xcode target tarafından iki kez mi alınıyor
- [ ] Eski/legacy varyantı var mı

#### Beklenen doğru durum
- SyncClient tek fiziksel kaynak olarak derlenir
- `flushOutbox` owner’ı nettir

#### Bulgu → düzeltme
- Duplicate referansları kaldır
- `flushOutbox` owner’ını sabitle

### 11. ios/QuantumAIMobile/QuantumAIMobile/SyncKit/RemoteMonitor.swift
#### Kontrol checklist
- [ ] `UIDevice` erişimi doğru platform/import hattında mı
- [ ] `watchlist` AppEnvironment üstünden mi geliyor
- [ ] main actor state actor dışından mı okunuyor

#### Beklenen doğru durum
- RemoteMonitor ortak state’i güvenli yüzeyden okur
- Cihaz bilgisi wrapper veya uygun platform katmanından gelir

#### Bulgu → düzeltme
- `watchlist` erişimini canonical AppEnvironment surface’e bağla
- Actor izolasyonunu düzelt

## Faz 4 — Tüketici katmanı onarımı

### 12. ios/QuantumAIMobile/QuantumAIMobile/ObservabilityKit/HealthPanelModel.swift
#### Kontrol checklist
- [ ] `$outbox` beklentisi güncel mi
- [ ] StorageService publisher/property isimleriyle uyumlu mu

#### Beklenen doğru durum
- HealthPanelModel yalnız güncel public surface’i kullanır

#### Bulgu → düzeltme
- Yalnız tüketici katmanını uyumlandır

### 13. ios/QuantumAIMobile/QuantumAIMobile/BotKit/BotService.swift
### 14. ios/QuantumAIMobile/QuantumAIMobile/BotKit/CopyTradeService.swift
#### Kontrol checklist
- [ ] `append` çağrısı güncel mi
- [ ] `marketBuy/limit/marketCopy` enum namespace’i doğru mu
- [ ] StorageService ile kontrat aynı mı

#### Beklenen doğru durum
- Bot servisleri storage/outbox yüzeyine canonical API ile bağlanır

#### Bulgu → düzeltme
- Eski append surface’ini bırak
- Enum owner’ını sabitle

## Faz 5 — Eksik UI ve adapter tiplerini geri bağla

### 15. ios/QuantumAIMobile/QuantumAIMobile/AppShell/LoginView.swift
#### Kontrol checklist
- [ ] Dosya target içinde mi
- [ ] `autocapitalization` ve `textInputAutocapitalization` hedef sürüme uygun mu
- [ ] Yanlış conditional compilation var mı

#### Beklenen doğru durum
- LoginView target içinde olur
- Modifier seti hedef platform/sürümle uyumludur

#### Bulgu → düzeltme
- Önce target üyeliğini düzelt
- Sonra modifier’ı sadeleştir

### 16. ios/QuantumAIMobile/QuantumAIMobile/AppShell/BinanceMasterPanel.swift
### 17. ios/QuantumAIMobile/QuantumAIMobile/AppShell/DashboardView.swift
#### Kontrol checklist
- [ ] `SummaryStatCard`, `TerminalStatCard`, `PerformanceChart`, `sampleData` gerçekten var mı
- [ ] Bu dosyalar package exclude listesinde mi
- [ ] `watchlist` kullanımı canonical owner’dan mı geliyor

#### Beklenen doğru durum
- UI bileşenleri ya target içinde geri alınmıştır ya da çağrılar kaldırılmıştır
- Aynı anda hem exclude edilip hem kullanılmaz

#### Bulgu → düzeltme
- Ya bileşeni geri al
- Ya bağımlılığı kaldır
- İkisini birden yapma

### 18. ios/QuantumAIMobile/QuantumAIMobile/MarketKit/MarketDataService.swift
#### Kontrol checklist
- [ ] `BinanceAdapter` fiziksel olarak var mı
- [ ] Doğru target/package kapsamına giriyor mu
- [ ] Closure type inference adapter eksikliğinin yan etkisi mi

#### Beklenen doğru durum
- MarketDataService tek adapter surface’ine bağlanır
- Concrete tip yerine mümkünse protocol kullanılır

#### Bulgu → düzeltme
- Önce adapter dosyası bulunur ve scope doğrulanır
- Sonra protocol/canonical adapter yüzeyi oturtulur

## Faz 6 — Sadece code build doğrulaması

### 19. Build komutu
#### Kontrol checklist
- [ ] Yalnız simulator/generic build mi alınıyor
- [ ] Signing/devices devre dışı mı
- [ ] Amaç yalnız code compile doğrulaması mı

#### Beklenen doğru durum
- Code build temiz geçerse source triage tamamdır
- Device/provisioning hatası bu aşamada görünmez

#### Bulgu → düzeltme
- Build hâlâ kırılıyorsa signing’e geçme
- Karar ağacına göre ilgili faza geri dön

## Faz 7 — Device / provisioning / archive

### 20. ios/QuantumAIMobileApp signing ayarları
#### Kontrol checklist
- [ ] Team doğru mu
- [ ] Bundle ID doğru mu
- [ ] Automatically manage signing açık mı kapalı mı
- [ ] Seçili device profile içinde mi

#### Beklenen doğru durum
- Code build temizden sonra yalnız signing/device hattı kalır

#### Bulgu → düzeltme
- Auto signing ise Xcode yönetsin
- Manual signing ise cihazı ve profile’ı portalda güncelle
