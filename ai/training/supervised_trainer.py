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
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.metrics import accuracy_score
from sklearn.preprocessing import StandardScaler

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

try:
    import torch
    import torch.nn as nn
    from torch.utils.data import DataLoader, Dataset

    TORCH_AVAILABLE = True
except Exception:  # pragma: no cover
    torch = None
    nn = None
    Dataset = object
    DataLoader = object
    TORCH_AVAILABLE = False

FEATURE_EXCLUDE = {"open_time", "close_time", "dataset_generated_at", "symbol", "interval", "label", "future_return"}


if TORCH_AVAILABLE:
    class SequenceDataset(Dataset):
        def __init__(self, x: np.ndarray, y: np.ndarray):
            self.x = torch.tensor(x, dtype=torch.float32)
            self.y = torch.tensor(y, dtype=torch.long)

        def __len__(self) -> int:
            return self.x.shape[0]

        def __getitem__(self, idx: int):
            return self.x[idx], self.y[idx]


    class LSTMSignalModel(nn.Module):
        def __init__(self, input_size: int, hidden_size: int = 64, layers: int = 2, dropout: float = 0.2, classes: int = 3):
            super().__init__()
            self.lstm = nn.LSTM(input_size=input_size, hidden_size=hidden_size, num_layers=layers, dropout=dropout, batch_first=True)
            self.norm = nn.LayerNorm(hidden_size)
            self.head = nn.Sequential(
                nn.Linear(hidden_size, hidden_size),
                nn.GELU(),
                nn.Dropout(dropout),
                nn.Linear(hidden_size, classes),
            )

        def forward(self, x: "torch.Tensor") -> "torch.Tensor":
            out, _ = self.lstm(x)
            last = self.norm(out[:, -1, :])
            return self.head(last)


else:
    class LSTMSignalModel:  # pragma: no cover - lightweight stub
        def __init__(self, *args: Any, **kwargs: Any):
            raise RuntimeError("torch unavailable")


def load_latest_dataset(dataset_dir: Path) -> pd.DataFrame:
    files = sorted(dataset_dir.glob("*"))
    if not files:
        raise FileNotFoundError(f"dataset_not_found:{dataset_dir}")
    latest = files[-1]
    if latest.suffix == ".parquet":
        return pd.read_parquet(latest)
    return pd.read_csv(latest)


def build_labels(df: pd.DataFrame, horizon: int = 6, up_threshold: float = 0.004, down_threshold: float = -0.004) -> pd.DataFrame:
    out = df.copy()
    out["future_return"] = out["close"].shift(-horizon) / out["close"] - 1.0
    out["label"] = 1
    out.loc[out["future_return"] >= up_threshold, "label"] = 2
    out.loc[out["future_return"] <= down_threshold, "label"] = 0
    out = out.iloc[:-horizon].copy()
    return out


def feature_columns(df: pd.DataFrame) -> list[str]:
    cols: list[str] = []
    for col in df.columns:
        if col in FEATURE_EXCLUDE:
            continue
        if pd.api.types.is_numeric_dtype(df[col]):
            cols.append(col)
    return cols


def make_sequences(df: pd.DataFrame, cols: list[str], seq_len: int = 32) -> tuple[np.ndarray, np.ndarray]:
    x = df[cols].to_numpy(dtype=np.float32)
    y = df["label"].to_numpy(dtype=np.int64)
    xs, ys = [], []
    for i in range(seq_len, len(df)):
        xs.append(x[i - seq_len:i])
        ys.append(y[i])
    return np.array(xs, dtype=np.float32), np.array(ys, dtype=np.int64)


def split_train_val(x: np.ndarray, y: np.ndarray, ratio: float = 0.85) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    k = max(int(len(x) * ratio), 1)
    return x[:k], y[:k], x[k:], y[k:]


def train_with_torch(x_train: np.ndarray, y_train: np.ndarray, x_val: np.ndarray, y_val: np.ndarray, input_size: int, epochs: int, batch_size: int) -> tuple[Any, dict[str, float], str]:
    device = "cuda" if torch and torch.cuda.is_available() else "cpu"
    model = LSTMSignalModel(input_size=input_size).to(device)
    train_loader = DataLoader(SequenceDataset(x_train, y_train), batch_size=batch_size, shuffle=True, drop_last=False)
    val_loader = DataLoader(SequenceDataset(x_val, y_val), batch_size=batch_size, shuffle=False, drop_last=False)
    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.AdamW(model.parameters(), lr=1e-3, weight_decay=1e-4)
    best_loss = float("inf")
    best_state = None
    last_acc = 0.0

    for _ in range(epochs):
        model.train()
        for xb, yb in train_loader:
            xb = xb.to(device)
            yb = yb.to(device)
            optimizer.zero_grad(set_to_none=True)
            loss = criterion(model(xb), yb)
            loss.backward()
            nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
            optimizer.step()

        model.eval()
        total_loss = 0.0
        correct = 0
        seen = 0
        with torch.no_grad():
            for xb, yb in val_loader:
                xb = xb.to(device)
                yb = yb.to(device)
                logits = model(xb)
                loss = criterion(logits, yb)
                total_loss += float(loss.item()) * len(xb)
                preds = torch.argmax(logits, dim=1)
                correct += int((preds == yb).sum().item())
                seen += len(xb)
        val_loss = total_loss / max(seen, 1)
        last_acc = correct / max(seen, 1)
        if val_loss < best_loss:
            best_loss = val_loss
            best_state = {k: v.detach().cpu().clone() for k, v in model.state_dict().items()}

    if best_state is not None:
        model.load_state_dict(best_state)
    return model, {"val_loss": best_loss, "val_acc": last_acc}, "torch_lstm"


def train_with_sklearn(x_train: np.ndarray, y_train: np.ndarray, x_val: np.ndarray, y_val: np.ndarray) -> tuple[Any, dict[str, float], str]:
    x_train_flat = x_train.reshape(x_train.shape[0], -1)
    x_val_flat = x_val.reshape(x_val.shape[0], -1)
    clf = HistGradientBoostingClassifier(max_depth=6, learning_rate=0.05, max_iter=250, random_state=42)
    clf.fit(x_train_flat, y_train)
    preds = clf.predict(x_val_flat)
    acc = accuracy_score(y_val, preds) if len(y_val) else 0.0
    return clf, {"val_loss": float(1.0 - acc), "val_acc": float(acc)}, "sklearn_hgb"


def train_from_root(root: Path) -> dict[str, Any]:
    dataset_dir = root / "ai" / "data" / "datasets"
    models_dir = root / "ai" / "models"
    models_dir.mkdir(parents=True, exist_ok=True)

    df = load_latest_dataset(dataset_dir)
    df = build_labels(
        df,
        horizon=int(os.getenv("QAI_LABEL_HORIZON", "6")),
        up_threshold=float(os.getenv("QAI_UP_THRESHOLD", "0.004")),
        down_threshold=float(os.getenv("QAI_DOWN_THRESHOLD", "-0.004")),
    )
    cols = feature_columns(df)
    scaler = StandardScaler()
    df = df.astype({col: np.float64 for col in cols}, copy=False)
    scaled_values = scaler.fit_transform(df[cols].astype(np.float64))
    df = df.copy()
    df.loc[:, cols] = pd.DataFrame(scaled_values, columns=cols, index=df.index)
    seq_len = int(os.getenv("QAI_SEQ_LEN", "32"))
    x, y = make_sequences(df, cols, seq_len=seq_len)
    x_train, y_train, x_val, y_val = split_train_val(x, y)

    if TORCH_AVAILABLE:
        model, metrics, model_type = train_with_torch(
            x_train,
            y_train,
            x_val,
            y_val,
            input_size=len(cols),
            epochs=int(os.getenv("QAI_EPOCHS", "12")),
            batch_size=int(os.getenv("QAI_BATCH", "64")),
        )
        model_path = models_dir / "supervised_lstm_signal.pt"
        torch.save(model.state_dict(), model_path)
    else:
        model, metrics, model_type = train_with_sklearn(x_train, y_train, x_val, y_val)
        model_path = models_dir / "supervised_signal.joblib"
        joblib.dump(model, model_path)

    scaler_path = models_dir / "supervised_scaler.joblib"
    meta_path = models_dir / "supervised_meta.json"
    joblib.dump(scaler, scaler_path)
    meta = {
        "feature_columns": cols,
        "seq_len": seq_len,
        "classes": {"0": "sell", "1": "hold", "2": "buy"},
        "metrics": metrics,
        "rows": int(len(df)),
        "model_path": str(model_path),
        "scaler_path": str(scaler_path),
        "model_type": model_type,
        "torch_available": TORCH_AVAILABLE,
    }
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    return {"ok": True, "model": str(model_path), "scaler": str(scaler_path), "meta": str(meta_path), "metrics": metrics, "model_type": model_type}


def main() -> None:
    root = Path(os.getenv("QAI_ROOT", Path(__file__).resolve().parents[2]))
    print(json.dumps(train_from_root(root), ensure_ascii=False))


if __name__ == "__main__":
    main()
