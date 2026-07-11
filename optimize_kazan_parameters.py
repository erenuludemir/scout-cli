#!/usr/bin/env python3
"""
KAZAN ALGORİTMASI - PARAMETRELERİ SOTOMATİK OPTİMİZE ETME
Başarı oranı, hata kurtarma ve ROI'ye göre dinamik ayarlamalar
"""

import configparser
from pathlib import Path
from datetime import datetime
from typing import Dict, Tuple
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class KazanParameterOptimizer:

    def __init__(self, config_path: str):
        self.config = configparser.ConfigParser()
        self.config.read(config_path)

        # Mevcut parametreler
        self.current_params = {
            'max_leverage': float(self.config.get('LEVERAGE_OPTIMIZATION', 'max_leverage')),
            'min_signal_confidence': float(self.config.get('SIGNAL_QUALITY', 'min_signal_confidence')),
            'grid_min_count': int(self.config.get('GRID_OPTIMIZATION', 'grid_min_count')),
            'grid_max_count': int(self.config.get('GRID_OPTIMIZATION', 'grid_max_count')),
            'quantum_iterations': int(self.config.get('QUANTUM_OPTIMIZATION', 'quantum_iterations')),
            'retry_delay_seconds': int(self.config.get('ERROR_RECOVERY', 'retry_delay_seconds')),
        }

        # Hedefler
        self.targets = {
            'success_rate': float(self.config.get('TARGETS', 'success_rate_target')),
            'error_recovery': float(self.config.get('TARGETS', 'error_recovery_target')),
            'expected_roi': float(self.config.get('PERFORMANCE_TARGETS', 'expected_roi_per_cycle')),
        }

        self.optimization_history = []

    def evaluate_metrics(self, metrics: Dict) -> Dict:
        """Metrikleri hedeflerle karşılaştır"""
        success_rate = metrics.get('success_rate', 0)
        error_recovery = metrics.get('error_recovery_rate', 0)
        actual_roi = metrics.get('actual_roi_per_cycle', 0)

        return {
            'success_rate': {
                'current': success_rate,
                'target': self.targets['success_rate'],
                'gap': self.targets['success_rate'] - success_rate,
                'status': 'OK' if success_rate >= self.targets['success_rate'] else 'KRITIK'
            },
            'error_recovery': {
                'current': error_recovery,
                'target': self.targets['error_recovery'],
                'gap': self.targets['error_recovery'] - error_recovery,
                'status': 'OK' if error_recovery >= self.targets['error_recovery'] else 'UYARI'
            },
            'roi': {
                'current': actual_roi,
                'target': self.targets['expected_roi'],
                'gap': self.targets['expected_roi'] - actual_roi,
                'status': 'OK' if actual_roi >= self.targets['expected_roi'] else 'DÜŞÜK'
            }
        }

    def optimize_parameters(self, metrics: Dict, volatility: float) -> Tuple[Dict, list]:
        """Parametreleri otomatik olarak optimize et"""
        evaluation = self.evaluate_metrics(metrics)
        adjustments = []

        # KURAL 1: Başarı oranı < %95 ise parametreleri sıkı ayarla
        if evaluation['success_rate']['gap'] > 0:
            logger.warning(f"⚠️ BAŞARI ORANI DÜŞÜK: {evaluation['success_rate']['current']*100:.1f}% (Hedef: {evaluation['success_rate']['target']*100:.0f}%)")

            # Güven eşiğini azalt (daha fazla sinyal kabul et)
            old_confidence = self.current_params['min_signal_confidence']
            self.current_params['min_signal_confidence'] = max(0.50, old_confidence - 0.02)
            adjustments.append(f"Minimum sinyal güveni: {old_confidence:.2f} → {self.current_params['min_signal_confidence']:.2f}")

            # Grid aralığını kapat (daha sık işlemler)
            if self.current_params['grid_max_count'] < 30:
                self.current_params['grid_max_count'] += 2
                adjustments.append(f"Max grid count: +2 (Toplam: {self.current_params['grid_max_count']})")

            # Kaldıraçı azalt (risk azalt)
            old_leverage = self.current_params['max_leverage']
            self.current_params['max_leverage'] = max(2.0, old_leverage - 0.5)
            adjustments.append(f"Maksimum leverage: {old_leverage:.1f}x → {self.current_params['max_leverage']:.1f}x")

        # KURAL 2: Volatilite yüksek ise (>0.03)
        if volatility > 0.03:
            logger.warning(f"⚠️ YÜKSEK VOLATİLİTE: {volatility:.2%}")

            old_leverage = self.current_params['max_leverage']
            self.current_params['max_leverage'] = max(1.5, old_leverage * 0.8)
            adjustments.append(f"Volatilite yüksek → Leverage azaltma: {old_leverage:.1f}x → {self.current_params['max_leverage']:.1f}x")

            # Güven eşiğini artır (daha seçici)
            old_confidence = self.current_params['min_signal_confidence']
            self.current_params['min_signal_confidence'] = min(0.70, old_confidence + 0.03)
            adjustments.append(f"Volatilite yüksek → Sinyal güveni artırma: {old_confidence:.2f} → {self.current_params['min_signal_confidence']:.2f}")

        # KURAL 3: Hata kurtarma < %98 ise
        if evaluation['error_recovery']['gap'] > 0:
            logger.warning(f"⚠️ HATA KURTARMA YETERSIZ: {evaluation['error_recovery']['current']*100:.1f}% (Hedef: {evaluation['error_recovery']['target']*100:.0f}%)")

            old_retry = self.current_params['retry_delay_seconds']
            self.current_params['retry_delay_seconds'] = min(15, old_retry + 2)
            adjustments.append(f"Retry delay: {old_retry}s → {self.current_params['retry_delay_seconds']}s")

            old_iterations = self.current_params['quantum_iterations']
            self.current_params['quantum_iterations'] = min(400, old_iterations + 50)
            adjustments.append(f"Quantum iterasyon: {old_iterations} → {self.current_params['quantum_iterations']}")

        # KURAL 4: ROI target'e ulaşmadı ise
        if evaluation['roi']['gap'] > 0:
            logger.warning(f"📈 ROI DÜŞÜK: {evaluation['roi']['current']*100:.2f}% (Hedef: {evaluation['roi']['target']*100:.2f}%)")

            # Grid count'ı artır
            if self.current_params['grid_min_count'] < 12:
                self.current_params['grid_min_count'] += 1
                adjustments.append("Min grid count: +1 (Daha sık işlemler)")

            old_iterations = self.current_params['quantum_iterations']
            self.current_params['quantum_iterations'] = min(500, old_iterations + 50)
            adjustments.append(f"Quantum iterasyon (AI optimize): {old_iterations} → {self.current_params['quantum_iterations']}")

        # Başarı oranı yüksek ise (>95%) biraz daha risk alalabiliriz
        if evaluation['success_rate']['status'] == 'OK' and volatility < 0.02:
            logger.info(f"✅ BAŞARI ORANI İYİ: {evaluation['success_rate']['current']*100:.1f}%")

            if self.current_params['max_leverage'] < 5.0:
                old_leverage = self.current_params['max_leverage']
                self.current_params['max_leverage'] = min(5.0, old_leverage + 0.3)
                adjustments.append(f"Başarılı operasyon → Leverage artırma: {old_leverage:.1f}x → {self.current_params['max_leverage']:.1f}x")

        # Optimizasyon geçmişine kaydet
        self.optimization_history.append({
            'timestamp': datetime.now().isoformat(),
            'metrics': evaluation,
            'volatility': volatility,
            'adjustments': adjustments
        })

        return self.current_params, adjustments

    def generate_report(self, metrics: Dict, volatility: float) -> str:
        """Optimizasyon raporunu oluştur"""
        params, adjustments = self.optimize_parameters(metrics, volatility)
        evaluation = self.evaluate_metrics(metrics)

        report = f"""
╔══════════════════════════════════════════════════════════════╗
║          KAZAN ALGORİTMASI - OPTİMİZASYON RAPORU           ║
║                    {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}                   ║
╚══════════════════════════════════════════════════════════════╝

📊 METRIK DEĞERLENDİRMESİ:
─────────────────────────────────────────────────────────────

✓ BAŞARI ORANI: {evaluation['success_rate']['current']*100:.1f}%
  └─ Hedef: {evaluation['success_rate']['target']*100:.0f}%
  └─ Durum: {evaluation['success_rate']['status']}

✓ HATA KURTARMA: {evaluation['error_recovery']['current']*100:.1f}%
  └─ Hedef: {evaluation['error_recovery']['target']*100:.0f}%
  └─ Durum: {evaluation['error_recovery']['status']}

✓ GERÇEK ROI: {evaluation['roi']['current']*100:.2f}%
  └─ Hedef: {evaluation['roi']['target']*100:.2f}%
  └─ Durum: {evaluation['roi']['status']}

📈 PAZAR KOŞULLARI:
─────────────────────────────────────────────────────────────
  Volatilite: {volatility:.2%}
  ├─ Yüksek (>3%): Riskli → Kaldıraç azalt ✓
  └─ Düşük (<1%): Güvenli → Kaldıraç artır ✓

⚙️ YAPILAN OPTİMİZASYONLAR:
─────────────────────────────────────────────────────────────
"""
        if adjustments:
            for adj in adjustments:
                report += f"  ✓ {adj}\n"
        else:
            report += "  ✓ Parametreler optimal durumda\n"

        report += f"""
🎯 GÜNCEL PARAMETRELERİ:
─────────────────────────────────────────────────────────────
  Grid:
    ├─ Min Count: {params['grid_min_count']}
    └─ Max Count: {params['grid_max_count']}

  Leverage:
    └─ Max: {params['max_leverage']:.1f}x

  Signal:
    └─ Min Confidence: {params['min_signal_confidence']:.2f}

  Quantum:
    └─ Iterations: {params['quantum_iterations']}

  Recovery:
    └─ Retry Delay: {params['retry_delay_seconds']}s

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""
        return report


def main():
    config_path = '/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/kazan_optimization.conf'

    optimizer = KazanParameterOptimizer(config_path)

    # Örnek metrikler (gerçekte Docker logs'tan alınır)
    example_metrics = {
        'success_rate': 0.92,  # %92 (hedef %95)
        'error_recovery_rate': 0.96,  # %96 (hedef %98)
        'actual_roi_per_cycle': 0.015,  # %1.5 (hedef %2)
    }

    volatility = 0.025  # %2.5 volatility

    report = optimizer.generate_report(example_metrics, volatility)
    print(report)

    # Raporası kaydet
    report_path = Path('/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/_reports')
    report_path.mkdir(exist_ok=True)

    report_file = report_path / f"kazan_optimization_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    with open(report_file, 'w') as f:
        f.write(report)

    print(f"\n💾 Rapor kaydedildi: {report_file}")


if __name__ == '__main__':
    main()
