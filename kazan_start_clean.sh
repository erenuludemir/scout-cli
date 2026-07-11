#!/bin/bash
# KAZAN ALGORİTMASI - CLEAN RESTART
# Tüm eski hizmetleri kapat, portları temizle, yeniden başlat

PROJECT_ROOT="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
unset COMPOSE_FILE

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        🚀 KAZAN ALGORİTMASI - TEMIZ BAŞLANGAÇ                ║"
echo "║                                                                ║"
echo "║  Eski hizmetler temizleniyor, portlar serbest bırakılıyor   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Adım 1: Docker daemon kontrol
echo "1️⃣ Docker Daemon Kontrolü"
if ! docker ps &> /dev/null; then
    echo "   ❌ Docker çalışmıyor!"
    exit 1
fi
echo "   ✅ Docker aktif"
echo ""

# Adım 2: Tüm eski hizmetleri durdur
echo "2️⃣ Eski Hizmetler Temizleniyor"
cd "$PROJECT_ROOT"

echo "   🔄 docker compose down komutu çalıştırılıyor..."
docker compose -f compose.yml -p quantumai-stack down --remove-orphans 2>&1 | grep -E "(Removing|Stopping|Removing container)" | tail -5

echo "   ⏳ Portların serbest bırakılması bekleniyor (5 saniye)..."
sleep 5

# Adım 3: Opsiyonel: Duramlı konteyner kayıtlarını temizle
echo "   🧹 Durmuş konteyner kayıtları temizleniyor..."
docker container prune -f --filter "label!=persist" 2>&1 | grep -E "Total|deleted" | head -1

sleep 2
echo "   ✅ Eski hizmetler temizlendi"
echo ""

# Adım 4: Yeni hizmetleri başlat
echo "3️⃣ Yeni Hizmetler Başlatılıyor"
echo "   🚀 docker compose up -d"
docker compose -f compose.yml -p quantumai-stack up -d 2>&1 | grep -E "^(
 ✔|✘|\[)" | head -20

echo "   ⏳ Hizmetlerin başlaması bekleniyor (30 saniye)..."
sleep 30

echo "   ✅ Hizmetler başlatıldı"
echo ""

# Adım 5: Kritik hizmet kontrolü
echo "4️⃣ Hizmet Durumu"

# Sistemin temel olarak çalışıp çalışmadığını kontrol et
RUNNING=$(docker compose -f compose.yml -p quantumai-stack ps --services --filter "status=running" | wc -l)

if [ "$RUNNING" -gt 0 ]; then
    echo "   ✅ $RUNNING hizmet çalışıyor"
    echo ""
    echo "   Çalışan hizmetler:"
    docker compose -f compose.yml -p quantumai-stack ps --services --filter "status=running" | sed 's/^/      ✓ /'
else
    echo "   ⚠️  Hiçbir hizmet çalışmıyor"
    docker compose -f compose.yml -p quantumai-stack logs --tail 20
    exit 1
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo "5️⃣ MONİTÖRÜNG SEÇENEĞ İ"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "🚀 Kazan Algoritması Hazır!"
echo ""
echo "Monitoring seçin:"
echo "  A) Real-time Monitoring (Python - ÖNERİLEN)"
echo "  B) Docker Logs (Direkt izleme)"
echo "  C) Parameter Optimization (Oto-tune)"
echo "  S) Skip (background'da çalıştır)"
echo ""

# Monitoring seçeneği
read -p "Seçim (A/B/C/S): " -t 30 choice

case "${choice:-A}" in
    A|a)
        echo ""
        echo "🚀 Python Real-Time Monitoring başlatılıyor..."
        echo "   (Ctrl+C ile çıkabilirsin)"
        echo ""
        exec python3 monitor_kazan_algorithm.py
        ;;
    B|b)
        echo ""
        echo "🚀 Docker Logs başlatılıyor..."
        echo "   (Ctrl+C ile çıkabilirsin)"
        echo ""
        exec docker compose -f compose.yml -p quantumai-stack logs --follow --tail 200
        ;;
    C|c)
        echo ""
        echo "🚀 Parameter Optimization başlatılıyor..."
        echo "   (Ctrl+C ile çıkabilirsin)"
        echo ""
        while true; do
            echo ""
            python3 optimize_kazan_parameters.py
            echo "   ⏳ 30 saniye sonra yeniden optimizasyon yapılacak..."
            sleep 30
        done
        ;;
    S|s|*)
        echo ""
        echo "✅ Sistem background'da çalışıyor!"
        echo ""
        echo "Monitoring'i başka bir terminalde başlatmak için:"
        echo "  python3 monitor_kazan_algorithm.py"
        echo ""
        ;;
esac
