from __future__ import annotations

from .config import QuantumAITradingConfig
from .datasets import build_training_dataset, latest_feature_row
from .quantum_optimizer import quantum_inspired_grid_search
from .schemas import GridPlan


class GridLeverageEngine:
    def __init__(self, config: QuantumAITradingConfig):
        self.config = config

    def recommend(self, capital: float | None = None) -> GridPlan:
        capital = float(capital or self.config.grid_default_capital)
        df = build_training_dataset(self.config)
        row = latest_feature_row(df)
        spot_price = float(df.iloc[-1]["close"])
        volatility = max(0.005, float(row["volatility_24"]))

        candidate = quantum_inspired_grid_search(
            spot_price=spot_price,
            volatility=volatility,
            min_grid=self.config.grid_min_count,
            max_grid=self.config.grid_max_count,
            max_leverage=self.config.max_leverage,
            iterations=self.config.quantum_iterations,
        )

        width_pct = (candidate.upper - candidate.lower) / spot_price
        spacing_pct = width_pct / max(1, candidate.grid_count - 1)
        per_grid_capital = capital / candidate.grid_count
        expected_cycle_return_pct = spacing_pct * candidate.leverage * 0.65

        notes = [
            "Quantum-inspired annealing ile grid parametre optimizasyonu yapildi",
            "Volatilite yuksek oldugunda grid araligi genisletildi",
            "Kaldirac volatiliteye gore dinamik sinirlanir",
        ]
        if volatility > 0.03:
            notes.append("Yuksek volatilite nedeniyle stop sarti agresif tutulmali")
        if row["macro_risk_index"] > 0.4:
            notes.append("Makro risk yukseldigi icin kademeli emir onerilir")

        stop_mode = "TRAILING_HARD_STOP" if volatility > 0.025 else "SOFT_STOP_AND_RECENTER"

        return GridPlan(
            symbol=self.config.symbol,
            lower_price=round(candidate.lower, 4),
            upper_price=round(candidate.upper, 4),
            grid_count=int(candidate.grid_count),
            capital=round(capital, 2),
            leverage=round(candidate.leverage, 2),
            per_grid_capital=round(per_grid_capital, 2),
            spacing_pct=round(spacing_pct, 6),
            expected_cycle_return_pct=round(expected_cycle_return_pct, 6),
            stop_mode=stop_mode,
            notes=notes,
        )

    def liquidation_buffer_pct(self, leverage: float, volatility: float) -> float:
        base = max(0.01, volatility * 3.5)
        return round(min(0.25, base + max(0.0, leverage - 1.0) * 0.01), 4)

    def leverage_recommendation(self) -> dict:
        df = build_training_dataset(self.config)
        row = latest_feature_row(df)
        volatility = float(row["volatility_24"])
        confidence_adj = max(0.0, 0.8 - volatility * 15.0)
        leverage = min(
            self.config.max_leverage,
            max(self.config.min_leverage, 1.0 + confidence_adj * 3.0),
        )
        return {
            "symbol": self.config.symbol,
            "volatility_24": round(volatility, 6),
            "recommended_leverage": round(leverage, 2),
            "liquidation_buffer_pct": self.liquidation_buffer_pct(leverage, volatility),
            "notes": [
                "Kaldirac onerisi volatilite ve temkin katsayisina gore uretilir",
                "Yuksek oynaklikta kaldirac otomatik dusurulur",
            ],
        }
