#!/usr/bin/env python3
"""
KAZAN ALGORİTMASI - GERÇEKTİME MONİTÖRÜNÜ
Grid Trading with ML Signals - Başarı/Hata İzleme Sistemi
"""

import subprocess
import json
import re
import sys
from datetime import datetime
from collections import defaultdict
import threading
import time


class KazanMonitor:

    def __init__(self):
        self.metrics = {
            'total_signals': 0,
            'successful_trades': 0,
            'failed_trades': 0,
            'error_recovery': 0,
            'grid_cycles': 0,
            'leverage_adjustments': 0
        }
        self.errors = defaultdict(int)
        self.recent_signals = []
        self.lock = threading.Lock()

        # Hedef Metrikler
        self.target_success_rate = 0.95  # %95 başarı
        self.target_error_recovery = 0.98  # %5 başarısız işlemin %98'i çözülmeli

    def parse_signal_file(self, signal_path):
        """Signal JSON dosyasını parse et"""
        try:
            with open(signal_path) as f:
                signal = json.load(f)
                return {
                    'timestamp': signal.get('timestamp'),
                    'confidence': signal.get('confidence', 0),
                    'expected_return': signal.get('expected_return', 0),
                    'leverage': signal.get('leverage', 1.0),
                    'grid_count': signal.get('grid_count', 0)
                }
        except Exception:
            return None

    def process_log_line(self, line):
        """Docker log satırını işle ve metrikleri çıkar"""
        with self.lock:
            # Signal üretimi
            if 'Signal generated' in line or 'SIGNAL:' in line:
                self.metrics['total_signals'] += 1
                self.recent_signals.append({
                    'time': datetime.now(),
                    'content': line[:100]
                })

            # Başarılı işlemler
            if 'Trade executed successfully' in line or 'SUCCESS:' in line:
                self.metrics['successful_trades'] += 1

            # Başarısız işlemler
            elif 'Trade failed' in line or 'FAILED:' in line:
                self.metrics['failed_trades'] += 1

            # Hata kurtarma
            if 'Error recovery' in line or 'Recovered from' in line:
                self.metrics['error_recovery'] += 1

            # Grid döngüleri
            if 'Grid cycle completed' in line or 'Grid rebalance' in line:
                self.metrics['grid_cycles'] += 1

            # Leverage ayarları
            if 'Leverage adjusted' in line or 'leverage:' in line.lower():
                self.metrics['leverage_adjustments'] += 1

            # Hata türleri
            error_patterns = {
                'connection_error': r'(connection|timeout|refused)',
                'balance_error': r'(insufficient|balance)',
                'liquidation_risk': r'(liquidation|margin call)',
                'signal_error': r'(signal|confidence low)',
                'grid_error': r'(grid|spacing)',
            }

            for error_type, pattern in error_patterns.items():
                if re.search(pattern, line, re.IGNORECASE):
                    self.errors[error_type] += 1

    def calculate_success_rate(self):
        """Başarı oranını hesapla"""
        total = self.metrics['successful_trades'] + self.metrics['failed_trades']
        if total == 0:
            return 0
        return self.metrics['successful_trades'] / total

    def calculate_error_recovery_rate(self):
        """Hata kurtarma oranını hesapla"""
        if self.metrics['failed_trades'] == 0:
            return 1.0
        return self.metrics['error_recovery'] / self.metrics['failed_trades']

    def print_status(self):
        """Gerçek zamanlı durum göster"""
        success_rate = self.calculate_success_rate()
        recovery_rate = self.calculate_error_recovery_rate()

        # Hedef durumunu kontrol et
        success_ok = success_rate >= self.target_success_rate
        recovery_ok = recovery_rate >= self.target_error_recovery

        print("\n" + "="*70)
        print("🎯 KAZAN ALGORİTMASI - REAL-TIME İZLEME")
        print("="*70)

        print("\n📊 SINYAL VE TİCARET METRİKLERİ:")
        print(f"  • Toplam Sinyal: {self.metrics['total_signals']}")
        print(f"  • Başarılı İşlemler: {self.metrics['successful_trades']}")
        print(f"  • Başarısız İşlemler: {self.metrics['failed_trades']}")
        print(f"  • Hata Kurtarılan: {self.metrics['error_recovery']}")

        print(f"\n✅ BAŞARI ORANI: {success_rate*100:.1f}% {'✓ HEDEF ÜZERİ' if success_ok else '✗ ARTIŞ GEREKLİ'}")
        print(f"   Hedef: {self.target_success_rate*100:.0f}%")

        print(f"\n🔧 HATA KURTARMA: {recovery_rate*100:.1f}% {'✓ HEDEF ÜZERİ' if recovery_ok else '✗ ARTIŞ GEREKLİ'}")
        print(f"   Hedef: {self.target_error_recovery*100:.0f}%")

        print("\n⚙️ GRID VE LEVERAGE:")
        print(f"  • Grid Döngüleri: {self.metrics['grid_cycles']}")
        print(f"  • Leverage Ayarlamaları: {self.metrics['leverage_adjustments']}")

        if self.errors:
            print("\n⚠️ HATA DAĞILIMI:")
            for error_type, count in sorted(self.errors.items(), key=lambda x: x[1], reverse=True):
                print(f"  • {error_type}: {count}")

        print("\n" + "="*70)


def run_docker_logs():
    """Docker logs streamini başlat"""
    cmd = [
        'docker', 'compose',
        '--file', '/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/compose.yml',
        '--project-name', 'quantumai-stack',
        'logs', '--follow', '--tail', '1000'
    ]

    monitor = KazanMonitor()
    print("🚀 Docker logs başlatılıyor...")
    print("📡 Kazan Algoritması izlemesi aktif...")

    # Metrikleri periyodik olarak göster
    def metrics_printer():
        while True:
            time.sleep(30)
            monitor.print_status()

    metrics_thread = threading.Thread(target=metrics_printer, daemon=True)
    metrics_thread.start()

    try:
        process = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1
        )

        for line in iter(process.stdout.readline, ''):
            if line:
                monitor.process_log_line(line)
                # Önemli satırları göster
                if any(keyword in line for keyword in ['SIGNAL:', 'SUCCESS:', 'FAILED:', 'Error', 'WARNING']):
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] {line.strip()}")

    except KeyboardInterrupt:
        print("\n\n🛑 Monitoring durduruldu.")
        monitor.print_status()
        sys.exit(0)
    except Exception as e:
        print(f"❌ Hata: {e}")
        sys.exit(1)


if __name__ == '__main__':
    run_docker_logs()
