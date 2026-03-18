#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

import joblib
import numpy as np
import pandas as pd

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from ai.quantum.quantum_optimizer import monte_carlo_stop_take
from ai.training.supervised_trainer import LSTMSignalModel, TORCH_AVAILABLE

if TORCH_AVAILABLE:
    import torch


def load_latest_dataset(dataset_dir: Path) -> pd.DataFrame:
    files = sorted(dataset_dir.glob("*"))
    if not files:
        raise FileNotFoundError(f"dataset_not_found:{dataset_dir}")
    latest = files[-1]
    if latest.suffix == ".parquet":
        return pd.read_parquet(latest)
    return pd.read_csv(latest)


def explain(row: pd.Series) -> list[str]:
    reasons: list[str] = []
    if float(row.get("rsi_14", 50.0)) < 35:
        reasons.append("RSI_asiri_satim_bolgesinde")
    if float(row.get("rsi_14", 50.0)) > 65:
        reasons.append("RSI_asiri_alim_bolgesinde")
    if float(row.get("macd_diff", 0.0)) > 0:
        reasons.append("MACD_pozitif_ivme")
    if float(row.get("macd_diff", 0.0)) < 0:
        reasons.append("MACD_negatif_ivme")
    if float(row.get("book_imbalance", 0.0)) > 0.10:
        reasons.append("emir_defteri_alis_yonlu")
    if float(row.get("book_imbalance", 0.0)) < -0.10:
        reasons.append("emir_defteri_satis_yonlu")
    if float(row.get("sentiment_score", 0.0)) > 0.25:
        reasons.append("haber_duyarliligi_olumlu")
    if float(row.get("sentiment_score", 0.0)) < -0.25:
        reasons.append("haber_duyarliligi_olumsuz")
    return reasons[:6]


def normalize_probabilities(raw_probs: np.ndarray, classes: np.ndarray | list[int] | tuple[int, ...] | None = None) -> np.ndarray:
    probs = np.asarray(raw_probs, dtype=np.float64).reshape(-1)
    if probs.size == 3 and classes is None:
        total = probs.sum()
        return probs / total if total > 0 else np.array([1 / 3, 1 / 3, 1 / 3], dtype=np.float64)

    normalized = np.zeros(3, dtype=np.float64)
    labels = np.asarray(classes if classes is not None else np.arange(probs.size), dtype=int).reshape(-1)
    for idx, label in enumerate(labels):
        if 0 <= int(label) <= 2 and idx < probs.size:
            normalized[int(label)] = float(probs[idx])
    total = normalized.sum()
    if total <= 0:
        return np.array([1 / 3, 1 / 3, 1 / 3], dtype=np.float64)
    return normalized / total


def generate_latest_signal(root: Path) -> dict[str, Any]:
    dataset_dir = root / "ai" / "data" / "datasets"
    models_dir = root / "ai" / "models"
    df = load_latest_dataset(dataset_dir)
    meta = json.loads((models_dir / "supervised_meta.json").read_text(encoding="utf-8"))
    scaler = joblib.load(models_dir / "supervised_scaler.joblib")
    cols = meta["feature_columns"]
    seq_len = int(meta["seq_len"])

    scaled = df.copy()
    scaled = scaled.astype({col: np.float64 for col in cols}, copy=False)
    scaled_values = scaler.transform(scaled[cols].astype(np.float64))
    scaled.loc[:, cols] = pd.DataFrame(scaled_values, columns=cols, index=scaled.index)
    window = scaled[cols].tail(seq_len).to_numpy(dtype=np.float32)

    if meta["model_type"] == "torch_lstm":
        if not TORCH_AVAILABLE:
            raise RuntimeError("torch_model_saved_but_torch_missing")
        tensor = torch.tensor(window[None, ...], dtype=torch.float32)
        model = LSTMSignalModel(input_size=len(cols))
        state = torch.load(models_dir / "supervised_lstm_signal.pt", map_location="cpu")
        model.load_state_dict(state)
        model.eval()
        with torch.no_grad():
            probs = normalize_probabilities(torch.softmax(model(tensor), dim=1).cpu().numpy()[0])
    else:
        model = joblib.load(Path(meta["model_path"]))
        probs = normalize_probabilities(model.predict_proba(window.reshape(1, -1))[0], getattr(model, "classes_", None))

    labels = ["SELL", "HOLD", "BUY"]
    idx = int(np.argmax(probs))
    current = df.iloc[-1]
    risk = monte_carlo_stop_take(df, float(current["close"]))
    payload = {
        "ok": True,
        "symbol": str(current.get("symbol", os.getenv("QAI_SYMBOL", "BTCUSDT"))),
        "interval": str(current.get("interval", os.getenv("QAI_INTERVAL", "1h"))),
        "signal": labels[idx],
        "confidence": round(float(probs[idx]), 4),
        "price": round(float(current["close"]), 8),
        "stop_loss": round(float(risk["stop_loss"]), 8),
        "take_profit": round(float(risk["take_profit"]), 8),
        "reasons": explain(current),
        "probabilities": {"SELL": round(float(probs[0]), 4), "HOLD": round(float(probs[1]), 4), "BUY": round(float(probs[2]), 4)},
        "risk": {"mc_p10": round(float(risk["mc_p10"]), 8), "mc_p50": round(float(risk["mc_p50"]), 8), "mc_p90": round(float(risk["mc_p90"]), 8)},
    }
    out = models_dir / "latest_signal.json"
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    return payload


def main() -> None:
    root = Path(os.getenv("QAI_ROOT", Path(__file__).resolve().parents[2]))
    print(json.dumps(generate_latest_signal(root), ensure_ascii=False))


if __name__ == "__main__":
    main()
