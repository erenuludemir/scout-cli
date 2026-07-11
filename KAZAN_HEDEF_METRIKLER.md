# KAZAN ALGORİTMASI - HEDEF METRİKLER VE BAŞARI KRİTERLERİ
## Aşağıda Bırakılan Sistemin Adım Adım İzlenmesi

---

## 📊 HEDEF 1: %95 BAŞARI ORANI
**Yapılan işlemlerin %95'i başarı ile sonuçlanacak**

### Hedef Sistem Yapısı:
```
TOTAL TRADES = 100
├─ SUCCESS ✅ = 95 (hedef)
└─ FAILED ❌ = 5 (toplam)
```

### Başarı Oranı Hesaplama:
```
Success Rate = (Successful Trades / Total Trades) × 100
Success Rate = (95 / 100) × 100 = 95%
```

### Bu Hedefe Nasıl Ulaşılır:

#### 1.1 - ML Sinyal Kalitesini Artırma
| Şu Anki | Hedef | Eylem |
|---------|-------|-------|
| Confidence: 0.58 | 0.65+ | Model eğitimini iyileştir |
| Accuracy: 62% | 72%+ | Daha iyi feature engineering |
| ROC-AUC: 0.68 | 0.78+ | Hyperparameter tuning |

**Dosya**: `quantum_ai_trading/train_bot_models.py`
```bash
python train_bot_models.py --epochs 150 --learning_rate 0.001 --early_stopping
```

#### 1.2 - Grid Parametreleri Optimizasyonu
```python
# Başarı oranı < 95% ise:
IF success_rate < 0.95:
    # Grid aralığını kapat (daha iyi entry points)
    grid_spacing *= 0.95

    # Grid count'ı artır (daha sık işlemler = daha az slippage)
    grid_count = min(30, grid_count + 2)

    # Minimum güven eşiğini azalt (daha fazla sinyal)
    min_confidence -= 0.02
```

#### 1.3 - Risk Kontrolü (Başarısızlıkları Azaltma)
```python
# Stop Loss Mekanizması
stop_loss_pct = 0.02  # %2 alt limit
take_profit_pct = 0.05  # %5 üst limit

# Volatilite Kontrolü
IF volatility > 0.03:  # %3'ten yüksek
    leverage *= 0.8  # Kaldıraç azalt
    grid_spacing *= 1.2  # Grid aralığı geniş tut

IF volatility < 0.01:  # %1'den düşük
    leverage = 5.0  # Maksimum kaldıraç
    grid_spacing *= 0.9  # Grid aralığı dar tut
```

**İzleme Dosyası**: `_reports/success_rate_*.json`

---

## 🔧 HEDEF 2: %98 HATA KURTARMA ORANI
**Başarısız işlemlerin %98'i hata analizi yapılarak çözümlenmeli**

### Hedef Sistem Yapısı:
```
FAILED TRADES = 5
├─ RECOVERED ✅ = 4.9 (%98 of 5)
└─ PERMANENT ❌ = 0.1 (%2 of 5)
```

### Hata Kurtarma Hesaplama:
```
Recovery Rate = (Recovered Errors / Total Errors) × 100
Recovery Rate = (4.9 / 5) × 100 = 98%
```

### Bu Hedefe Nasıl Ulaşılır:

#### 2.1 - Hata Türlerini Tanımla
```python
ERROR_TYPES = {
    'connection_error': {
        'frequency': 0.15,  # %15 hata
        'recovery': 'auto_retry',  # Oto-retry
        'target_recovery': 0.99   # %99 başarı
    },
    'balance_error': {
        'frequency': 0.10,  # %10 hata
        'recovery': 'rebalance',  # Bakiye yenile
        'target_recovery': 0.98
    },
    'liquidation_risk': {
        'frequency': 0.05,  # %5 hata
        'recovery': 'reduce_leverage',  # Kaldıraç azalt
        'target_recovery': 0.95
    },
    'signal_error': {
        'frequency': 0.02,  # %2 hata
        'recovery': 'resignal',  # Yeni sinyal
        'target_recovery': 0.90
    },
}
```

#### 2.2 - Otomatik Kurtarma Stratejileri

**Strategy 1: Otomatik Tekrar Deneme (Auto-Retry)**
```python
max_retry_attempts = 3
retry_delay = [5, 10, 20]  # Saniye cinsinden exponential backoff

for attempt in range(max_retry_attempts):
    try:
        execute_trade()
        break
    except ConnectionError:
        if attempt < max_retry_attempts - 1:
            sleep(retry_delay[attempt])
            continue
        else:
            log_permanent_error()
```

**Strategy 2: Yumuşak Durdurma ve Yeniden Merkezleme (Soft Stop & Recenter)**
```python
IF high_volatility AND position_in_loss:
    # 1. Pozisyonu kapat (soft stop)
    close_position()

    # 2. Bakiyeyi yenile
    rebalance_portfolio()

    # 3. Grid'i yeniden başlat (merkezle)
    reset_grid_with_new_center()
```

**Strategy 3: Kaldıraç Azaltma**
```python
IF margin_call_risk > 0.8:  # Likidasyondandan 20% uzak
    current_leverage = 2.0
    reduce_leverage(current_leverage * 0.5)  # 1.0x'e düşür

    # Varlıkları kurtarma moduna al
    enable_recovery_mode()
```

#### 2.3 - Hata İzleme Parametreleri

```
Hedef Başarı Oranları (Hata Türü Bazında):
├─ Connection Errors: 99% kurtarma (1% permenant)
├─ Balance Errors: 98% kurtarma (2% permanent)
├─ Liquidation Risks: 95% kurtarma (5% permanent)
├─ Signal Errors: 90% kurtarma (10% permanent)
│
└─ TOPLAMDA: 98% ortalama kurtarma
```

**Dosya**: `monitoring/error_recovery_*.json`

---

## 💰 HEDEF 3A: EXPECTED ROI (Dönem Başına)
**Varsayılan: %2 döngü başına ROI (Grid çevrimi başına)**

### ROI Hesaplama:
```
ROI_per_cycle = (Final_Balance - Initial_Balance) / Initial_Balance × 100

Örnek:
Initial: 1000 USD
Final: 1020 USD
ROI = (1020 - 1000) / 1000 × 100 = 2%
```

### ROI Optimizasyonu:
```python
# Hedef parametreler
expected_roi_per_cycle = 0.02  # %2
grid_count = 8  # Daha sık işlemler
grid_spacing = 0.005  # %0.5 aralık
max_leverage = 2.5  # Moderate kaldıraç

# ROI < %2 ise:
IF actual_roi < target_roi:
    # 1. Grid count'ı artır (daha sık işlemler)
    grid_count = min(30, grid_count + 3)

    # 2. Grid aralığını kapat (%0.3'e)
    grid_spacing *= 0.75

    # 3. Quantum iterasyon artır (daha iyi optimize)
    quantum_iterations += 100

    # 4. Kaldıraç ayarla (volatiliteye göre)
    IF volatility < 0.02:
        leverage = 3.0
    ELSE:
        leverage = 2.0
```

**Dosya**: `_reports/roi_analysis_*.json`

---

## 💰 HEDEF 3B: RISK TOLERANCE (Maksimum Leverage)
**Varsayılan: 5.0x Leverage (Max)**

### Leverage Ayarlama Kuralları:
```
VOLATILITE → LEVERAGE TABLOSU

Volatility     Safe Leverage   Max Leverage   Grid Spacing
─────────────────────────────────────────────────────────
< 0.01 (%1)   3.0x            5.0x           Dar (0.3%)
0.01-0.02     2.5x            4.0x           Normal (0.5%)
0.02-0.03     2.0x            3.0x           Geniş (0.7%)
> 0.03 (%3)   1.5x            2.0x           Çok Geniş (1.0%)
```

### Leverage Optimizasyonu Aksiyonları:
```python
# Her işlem öncesi:
current_leverage = calculate_safe_leverage(
    portfolio_size=10000,
    volatility=0.025,
    margin_buffer=0.20,  # Likidasyondan 20% uzak
    confidence=0.65
)

# Maksimum kontrol
max_leverage = 5.0
safe_leverage = min(current_leverage, max_leverage)

# Uygula
place_trade(amount=1000 * safe_leverage)
```

**Dosya**: `_reports/leverage_tracking_*.json`

---

## 📈 HEDEF 3C: GRID COUNT TERCİHLERİ
**Varsayılan: 6-30 Grid (Dynamic)**

### Grid Count Ayarlama:
```python
# Grid sayısı = işlem sıklığı x başarı

Durum                    Min Grid   Max Grid   Açıklama
──────────────────────────────────────────────────────
Düşük Volatilite        10         30         Sık işlemler
Normal                   8          20         Normal işlemler
Yüksek Volatilite        6          12         Nadir işlemler
Trendy Pazar             12         25         Trende katıl
```

### Grid Optimizasyonu:
```python
# Başarı oranı < 95% ise
IF success_rate < 0.95:
    grid_max_count = min(30, grid_max_count + 2)
    # Daha sık işlem = daha fazla başarı fırsatı

# ROI < 2% ise
IF actual_roi < 0.02:
    grid_count = increase_by(15%)
    # Daha sık işlem = daha fazla getiri

# Volatilite > 3% ise
IF volatility > 0.03:
    grid_count = max(6, grid_count - 3)
    # Daha nadir işlem = daha az risk
```

**Dosya**: `_reports/grid_optimization_*.json`

---

## 🎯 HEPSİNİ OPTIMIZE ETME STRATEJİSİ

```
┌─────────────────────────────────────────────────────────┐
│        KAZAN ALGORİTMASI - BÜTÜNLEŞIK OPTIMIZASYON      │
└─────────────────────────────────────────────────────────┘

BASAMAK 1: SINYAL KALİTESİNİ ARTTIR
├─ ML Model eğitin (accuracy 72%+)
├─ Feature engineering iyileştir
└─ Confidence threshold: 0.65+

       ↓ %95 Başarı Oranına Ulaş

BASAMAK 2: HATA KURTARMAYA ODAKLAN
├─ Oto-retry mekaniz. aktif et
├─ Stop-loss/profit seviyelerini set
└─ Makro risk kontrolü aktif et

       ↓ %98 Hata Kurtarma Oranına Ulaş

BASAMAK 3: GETIRI OPTİMİZASYONU
├─ Grid count dinamik ayarla (6-30)
├─ Leverage volatiliteye göre calibrate
└─ ROI hedefi %2/döngü tuttur

       ↓ %2+ ROI Hedefine Ulaş

BASAMAK 4: MONİTÖRÜNG VE FEEDBACK LOOP
├─ 30 saniyede 1 metrikleri yenile
├─ Parameter'leri otomatik ayarla
└─ Raporları kaydedip analiz et

       ↓ SÜRDÜRÜLEBİLİR BAŞARI
```

---

## 📋 İZLEME KONTROL LİSTESİ

```
Günlük Kontrol:
☐ Başarı oranı %95+ mi?
☐ Hata kurtarma %98+ mi?
☐ ROI %2+ mi?
☐ Leverage optimize mi?
☐ Grid count uygun mu?

Haftalık Kontrol:
☐ ML modelini yeniden eğit
☐ Quantum parameters optimize et
☐ Hata raporlarını analiz et
☐ Parametreleri ayarla

Aylık Kontrol:
☐ Tüm metrikleri gözden geçir
☐ Risk tolerance ayarını kontrol et
☐ Yeni signal sources ekle
☐ Disaster recovery planını test et
```

---

## 🚀 BAŞLATMA KOMUTU

```bash
# 1. Monitoring'i başlat
cd /Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221\ 3
python3 monitor_kazan_algorithm.py

# 2. Parametreleri optimize et (paralel)
python3 optimize_kazan_parameters.py

# 3. Raporları görüntüle
tail -f _reports/kazan_optimization_*.txt
```

---

## 📊 BAŞARI KRİTERLERİ

| Metrik | Başarısız | Uyarı | İyi | Mükemmel |
|--------|-----------|-------|------|----------|
| Success Rate | < 85% | 85-94% | 95%+ | 97%+ |
| Error Recovery | < 90% | 90-97% | 98%+ | 99%+ |
| ROI/Cycle | < 1% | 1-1.9% | 2%+ | 3%+ |
| Sharpe Ratio | < 0.8 | 0.8-1.2 | 1.5+ | 2.0+ |
| Max Drawdown | > 15% | 10-15% | < 10% | < 5% |
