from __future__ import annotations

from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import HistGradientBoostingClassifier, HistGradientBoostingRegressor
from sklearn.metrics import accuracy_score, mean_absolute_error, roc_auc_score
from sklearn.preprocessing import StandardScaler

from .config import QuantumAITradingConfig
from .datasets import FEATURE_COLUMNS, build_training_dataset, persist_dataset, persist_manifest
from .model_registry import ModelRegistry
from .rl_env import TradingRLEnv


def _split(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    split_idx = int(len(df) * 0.80)
    return df.iloc[:split_idx].copy(), df.iloc[split_idx:].copy()


def train_supervised_models(config: QuantumAITradingConfig) -> dict:
    df = build_training_dataset(config)
    persist_dataset(df, config.data_dir / "training_dataset.parquet")
    persist_manifest(config, df, config.data_dir / "training_manifest.json")

    train_df, test_df = _split(df)
    X_train = train_df[FEATURE_COLUMNS].astype(float).values
    X_test = test_df[FEATURE_COLUMNS].astype(float).values
    y_cls_train = train_df["label_up"].astype(int).values
    y_cls_test = test_df["label_up"].astype(int).values
    y_reg_train = train_df["future_return"].astype(float).values
    y_reg_test = test_df["future_return"].astype(float).values

    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    clf = HistGradientBoostingClassifier(
        max_depth=6,
        learning_rate=0.05,
        max_iter=250,
        random_state=42,
    )
    reg = HistGradientBoostingRegressor(
        max_depth=6,
        learning_rate=0.05,
        max_iter=300,
        random_state=42,
    )

    clf.fit(X_train_scaled, y_cls_train)
    reg.fit(X_train_scaled, y_reg_train)

    proba = clf.predict_proba(X_test_scaled)[:, 1]
    pred_cls = (proba >= 0.5).astype(int)
    pred_reg = reg.predict(X_test_scaled)

    metrics_cls = {
        "accuracy": float(accuracy_score(y_cls_test, pred_cls)),
        "roc_auc": float(roc_auc_score(y_cls_test, proba)) if len(np.unique(y_cls_test)) > 1 else 0.5,
    }
    metrics_reg = {
        "mae": float(mean_absolute_error(y_reg_test, pred_reg)),
        "mean_pred_return": float(np.mean(pred_reg)),
    }

    registry = ModelRegistry(config)
    trained_at = datetime.now(timezone.utc).isoformat()

    cls_artifact = registry.save_bundle(
        "direction_classifier",
        clf,
        scaler,
        {
            "symbol": config.symbol,
            "interval": config.interval,
            "trained_at": trained_at,
            "features": FEATURE_COLUMNS,
            "metrics": metrics_cls,
            "notes": {"target": "label_up"},
        },
    )
    reg_artifact = registry.save_bundle(
        "return_regressor",
        reg,
        scaler,
        {
            "symbol": config.symbol,
            "interval": config.interval,
            "trained_at": trained_at,
            "features": FEATURE_COLUMNS,
            "metrics": metrics_reg,
            "notes": {"target": "future_return"},
        },
    )

    return {
        "dataset_rows": int(len(df)),
        "classifier": asdict(cls_artifact),
        "regressor": asdict(reg_artifact),
    }


def train_rl_policy(config: QuantumAITradingConfig, episodes: int = 25) -> dict:
    df = build_training_dataset(config)
    env = TradingRLEnv(df)
    bins = 7
    q_table = np.zeros((bins, bins, bins, 3), dtype=np.float32)

    def discretize(state: np.ndarray) -> tuple[int, int, int]:
        rsi = state[FEATURE_COLUMNS.index("rsi_14")]
        macd_hist = state[FEATURE_COLUMNS.index("macd_hist")]
        vol = state[FEATURE_COLUMNS.index("volatility_24")]
        rsi_bin = min(bins - 1, max(0, int(rsi // (100 / bins))))
        macd_bin = min(bins - 1, max(0, int((macd_hist + 0.02) / 0.04 * bins)))
        vol_bin = min(bins - 1, max(0, int(min(vol, 0.2) / 0.2 * bins)))
        return rsi_bin, macd_bin, vol_bin

    alpha = 0.12
    gamma = 0.95
    epsilon = 1.0
    total_rewards = []

    for _ in range(episodes):
        state = env.reset()
        done = False
        total_reward = 0.0
        while not done:
            s = discretize(state)
            if np.random.rand() < epsilon:
                action_idx = np.random.randint(0, 3)
            else:
                action_idx = int(np.argmax(q_table[s]))
            action_map = {0: -1, 1: 0, 2: 1}
            action = action_map[action_idx]
            next_state, reward, done, _ = env.step(action)
            ns = discretize(next_state)
            q_table[s + (action_idx,)] = q_table[s + (action_idx,)] + alpha * (
                reward + gamma * np.max(q_table[ns]) - q_table[s + (action_idx,)]
            )
            state = next_state
            total_reward += reward
        epsilon = max(0.10, epsilon * 0.92)
        total_rewards.append(total_reward)

    rl_dir = config.model_dir / "rl_policy"
    rl_dir.mkdir(parents=True, exist_ok=True)
    out_path = rl_dir / "q_table.joblib"
    joblib.dump({"q_table": q_table, "bins": bins}, out_path)

    return {
        "policy_path": str(out_path),
        "episodes": episodes,
        "avg_reward": float(np.mean(total_rewards)),
        "last_reward": float(total_rewards[-1] if total_rewards else 0.0),
    }


def train_all(config: QuantumAITradingConfig) -> dict:
    supervised = train_supervised_models(config)
    rl = train_rl_policy(config)
    return {"supervised": supervised, "rl": rl}


if __name__ == "__main__":
    cfg = QuantumAITradingConfig(root_dir=Path.cwd())
    result = train_all(cfg)
    print(result)
