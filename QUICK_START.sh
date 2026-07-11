#!/usr/bin/env bash
# KAZAN ALGORİTMASI - BAŞLAT (Quick Start)
# Sistemi optimize etme ve monitoring'i çalıştır

set -e

PROJECT_DIR="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║        🚀 KAZAN ALGORİTMASI - BAŞLATMA SİSTEMİ              ║"
echo "║                                                               ║"
echo "║  Hedef: %95 başarı, %98 hata kurtarma, %2+ ROI             ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Komut 1: Docker Logs İzlemesi
echo "📡 KOMUT 1 - Docker Logs (Real-Time Monitoring)"
echo "─────────────────────────────────────────────────"
CMD1="docker compose --file '$PROJECT_DIR/compose.yml' --project-name 'quantumai-stack' logs --follow --tail 1000"
echo "🔧 Çalıştır:"
echo "   $CMD1"
echo ""

# Komut 2: Python Monitoring
echo "🐍 KOMUT 2 - Python Monitoring Script"
echo "─────────────────────────────────────────────────"
CMD2="cd '$PROJECT_DIR' && python3 monitor_kazan_algorithm.py"
echo "🔧 Çalıştır:"
echo "   $CMD2"
echo ""

# Komut 3: Parameter Optimization
echo "⚙️  KOMUT 3 - Parameter Optimization"
echo "─────────────────────────────────────────────────"
CMD3="cd '$PROJECT_DIR' && python3 optimize_kazan_parameters.py"
echo "🔧 Çalıştır:"
echo "   $CMD3"
echo ""

# Komut 4: Bash Script (Hepsi Birlikte)
echo "🎯 KOMUT 4 - Hepsi Birlikte (Bash Script)"
echo "─────────────────────────────────────────────────"
CMD4="bash '$PROJECT_DIR/start_kazan_monitoring.sh'"
echo "🔧 Çalıştır:"
echo "   $CMD4"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "📚 DOKÜMANTASYON FİLLERİ:"
echo "─────────────────────────────────────────────────"
echo "  1. $PROJECT_DIR/KAZAN_OPERATION_GUIDE.md"
echo "     └─ Detaylı başlatma ve operasyon rehberi"
echo ""
echo "  2. $PROJECT_DIR/KAZAN_HEDEF_METRIKLER.md"
echo "     └─ Hedef metrikler ve başarı kriterleri"
echo ""
echo "  3. $PROJECT_DIR/kazan_optimization.conf"
echo "     └─ Parametreler ve optimizasyon kuralları"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "⚡ HIZLI BAŞLAT (ÖNERİLEN):"
echo "─────────────────────────────────────────────────"
echo ""
echo "1️⃣  Docker hizmetlerini başlat:"
echo "    docker compose -f '$PROJECT_DIR/compose.yml' -p quantumai-stack up -d"
echo ""
echo "2️⃣  Monitoring'i çalıştır (Yeni terminal açarak):"
echo "    cd '$PROJECT_DIR'"
echo "    python3 monitor_kazan_algorithm.py"
echo ""
echo "3️⃣  Parameter'leri optimize et (Başka bir terminal):"
echo "    cd '$PROJECT_DIR'"
echo "    watch -n 30 'python3 optimize_kazan_parameters.py'"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "✨ BAŞARILI!"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "Sistem hazırdır. Raporları görüntülemek için:"
echo "  tail -f _reports/kazan_optimization_*.txt"
echo ""
