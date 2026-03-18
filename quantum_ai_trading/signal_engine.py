from __future__ import annotations

import json
from dataclasses import asdict
from datetime import datetime, timezone

import numpy as np

from .config import QuantumAITradingConfig
from .datasets import FEATURE_COLUMNS, build_training_dataset, latest_feature_row
from .model_registry import ModelRegistry
from .schemas import SignalDecision


class SignalEngine:
    def __init__(self, config: QuantumAITradingConfig):
        self.config = config
        self.registry = ModelRegistry(config)

    def _load_or_train_models(self):
        try:
            clf, scaler_cls, meta_cls = self.registry.load_latest("direction_classifier")
            reg, scaler_reg, meta_reg = self.registry.load_latest("return_regressor")
        except FileNotFoundError:
            from .trainer import train_all

            train_all(self.config)
            clf, scaler_cls, meta_cls = self.registry.load_latest("direction_classifier")
            reg, scaler_reg, meta_reg = self.registry.load_latest("return_regressor")
        return clf, scaler_cls, meta_cls, reg, scaler_reg, meta_reg

    def _explain(self, row: dict[str, float], confidence: float) -> tuple[str, list[str]]:
        reasons = []
        risk_flags = []

        if row["rsi_14"] < 34:
            reasons.append("RSI dusuk ve tepki potansiyeli olusuyor")
        elif row["rsi_14"] > 68:
            reasons.append("RSI yuksek ve duzeltme riski artiyor")

        if row["macd_hist"] > 0:
            reasons.append("MACD histogram pozitif bolgede")
        else:
            reasons.append("MACD histogram negatif bolgede")

        if row["sentiment_index"] > 0.15:
            reasons.append("Duygu analizi olumlu")
        elif row["sentiment_index"] < -0.15:
            reasons.append("Duygu analizi baskili")

        if row["macro_risk_index"] > 0.4:
            risk_flags.append("Makro risk yuksek")
        if row["volatility_24"] > 0.03:
            risk_flags.append("Volatilite yuksek")
        if confidence < self.config.min_signal_confidence:
            risk_flags.append("Guven skoru esik altina yakin")

        reason = "; ".join(reasons[:4]) if reasons else "Model coklu veri setinden sinyal uretti"
        return reason, risk_flags

    def generate(self) -> SignalDecision:
        df = build_training_dataset(self.config)
        row = latest_feature_row(df)
        features = np.array([[row[col] for col in FEATURE_COLUMNS]], dtype=float)

        clf, scaler_cls, meta_cls, reg, scaler_reg, _ = self._load_or_train_models()
        X_cls = scaler_cls.transform(features)
        X_reg = scaler_reg.transform(features)

        confidence_up = float(clf.predict_proba(X_cls)[0, 1])
        expected_return = float(reg.predict(X_reg)[0])

        net_score = expected_return
        net_score += row["sentiment_index"] * self.config.sentiment_weight
        net_score += row["staking_ratio_proxy"] * self.config.onchain_weight
        net_score -= row["macro_risk_index"] * self.config.macro_weight

        if confidence_up >= self.config.min_signal_confidence and net_score > 0:
            action = "BUY"
        elif confidence_up <= (1.0 - self.config.min_signal_confidence) and net_score < 0:
            action = "SELL"
        else:
            action = "HOLD"

        base_vol = max(0.002, row["volatility_24"])
        stop_loss_pct = float(np.clip(base_vol * 1.8, 0.004, 0.05))
        take_profit_pct = float(np.clip(abs(expected_return) * 1.7 + base_vol, 0.006, 0.08))

        raw_leverage = 1.0 + max(0.0, confidence_up - 0.5) * 6.0
        raw_leverage /= max(1.0, row["volatility_24"] * 35.0)
        leverage = float(np.clip(raw_leverage, self.config.min_leverage, self.config.max_leverage))
        if action == "HOLD":
            leverage = 1.0

        confidence = round(max(confidence_up, 1.0 - confidence_up), 4)
        reason, risk_flags = self._explain(row, confidence)

        decision = SignalDecision(
            symbol=self.config.symbol,
            interval=self.config.interval,
            action=action,
            confidence=confidence,
            expected_return=round(expected_return, 6),
            stop_loss_pct=round(stop_loss_pct, 4),
            take_profit_pct=round(take_profit_pct, 4),
            leverage=round(leverage, 2),
            reason=reason,
            feature_snapshot={key: round(float(value), 6) for key, value in row.items()},
            risk_flags=risk_flags,
            model_version=str(meta_cls.get("trained_at", "unknown")),
            mode="paper" if self.config.paper_trading_only else "live",
        )
        self._persist_signal(decision)
        return decision

    def _persist_signal(self, decision: SignalDecision) -> None:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        out = self.config.signal_dir / f"signal_{stamp}.json"
        out.write_text(json.dumps(asdict(decision), ensure_ascii=False, indent=2), encoding="utf-8")
