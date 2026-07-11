#!/bin/bash
# KAZAN ALGORİTMASI - BAŞLATMA VE MONİTÖRÜ BAŞLAT
# Sistem senkronizasyonu + Real-time algorithma izlemesi

set -e

PROJECT_ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
COMPOSE_FILE="$PROJECT_ROOT/compose.yml"
PROJECT_NAME="quantumai-stack"

echo "════════════════════════════════════════════════════════════"
echo "🚀 KAZAN ALGORİTMASI SİSTEMİ BAŞLATILIYOR"
echo "════════════════════════════════════════════════════════════"
echo ""

# Adım 1: Docker Daemon Kontrolü
echo "📋 Adım 1: Docker Daemon Kontrolü"
if ! docker ps &> /dev/null; then
    echo "⚠️ Docker daemon çalışmıyor, başlatılıyor..."
    open /Applications/Docker.app 2>/dev/null || echo "❌ Docker uygulaması bulunamadı"
    sleep 5
fi
echo "✅ Docker daemon aktif"
echo ""

# Adım 2: Docker Compose Hizmetlerini Başlat
echo "📋 Adım 2: Docker Hizmetleri Başlatılıyor"
echo "🔧 Komut: docker compose --file '$COMPOSE_FILE' --project-name '$PROJECT_NAME' up -d"
docker compose --file "$COMPOSE_FILE" --project-name "$PROJECT_NAME" up -d

# Hizmetlerin başlaması için bekle
echo "⏳ Hizmetlerin stabilize olması bekleniyor (30 saniye)..."
sleep 30

echo "✅ Docker hizmetleri başlatıldı"
echo ""

# Adım 3: Blockchain Ağı Kontrol ve Bağlantısı
echo "📋 Adım 3: Blockchain Ağı Bağlantısı"
if [ -z "$WEB3_PROVIDER_URI" ]; then
    echo "⚠️ WEB3_PROVIDER_URI ayarlanmamış. Örnek:"
    echo "   export WEB3_PROVIDER_URI='https://mainnet.infura.io/v3/YOUR_PROJECT_ID'"
else
    echo "✅ Web3 sağlayıcı: $WEB3_PROVIDER_URI"
fi
echo ""

# Adım 4: API Servisini Başlat
echo "📋 Adım 4: Kazan Algoritması Sistemi Başlatılıyor"
echo "📡 Gerçek-Zamanlı Monitoring Başlamak Üzere..."
echo ""

# Adım 5: Python Monitoring Script'i Çalıştır
echo "════════════════════════════════════════════════════════════"
echo "📊 KAZAN ALGORİTMASI - REAL-TIME İZLEME"
echo "════════════════════════════════════════════════════════════"
echo ""

cd "$PROJECT_ROOT"

# Monitoring scriptini başlat
if [ -f "monitor_kazan_algorithm.py" ]; then
    python3 monitor_kazan_algorithm.py
else
    echo "❌ monitor_kazan_algorithm.py bulunamadı!"
    echo "Alternatif olarak Docker logs izleniyor..."
    docker compose --file "$COMPOSE_FILE" --project-name "$PROJECT_NAME" logs --follow --tail 1000
fi
