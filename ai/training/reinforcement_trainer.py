#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

if __package__ in {None, ""}:
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))


@dataclass(slots=True)
class TradeEnvConfig:
    fee_bps: float = 4.0
    slippage_bps: float = 2.0
    risk_penalty: float = 0.10
    max_steps: int = 5000


class MarketEnv:
    def __init__(self, df: pd.DataFrame, config: TradeEnvConfig):
        self.df = df.reset_index(drop=True)
        self.cfg = config
        self.pointer = 30
        self.position = 0
        self.equity = 1.0
        self.done = False

    def reset(self) -> tuple[int, int, int]:
        self.pointer = 30
        self.position = 0
        self.equity = 1.0
        self.done = False
        return self.state()

    def state(self) -> tuple[int, int, int]:
        rsi = float(self.df.loc[self.pointer, "rsi_14"])
        macd = float(self.df.loc[self.pointer, "macd_diff"])
        vol = float(self.df.loc[self.pointer, "volatility_20"])
        vol_q70 = float(np.nanquantile(self.df["volatility_20"], 0.7))
        vol_q30 = float(np.nanquantile(self.df["volatility_20"], 0.3))
        rsi_bucket = 0 if rsi < 35 else 2 if rsi > 65 else 1
        macd_bucket = 2 if macd > 0 else 0 if macd < 0 else 1
        vol_bucket = 2 if vol > vol_q70 else 0 if vol < vol_q30 else 1
        return (rsi_bucket, macd_bucket, vol_bucket)

    def step(self, action: int) -> tuple[tuple[int, int, int], float, bool, dict[str, Any]]:
        if self.done:
            return self.state(), 0.0, True, {}
        price_now = float(self.df.loc[self.pointer, "close"])
        price_next = float(self.df.loc[self.pointer + 1, "close"])
        ret = (price_next / max(price_now, 1e-9)) - 1.0
        fee = (self.cfg.fee_bps + self.cfg.slippage_bps) / 10000.0

        reward = 0.0
        if action == 2 and self.position <= 0:
            self.position = 1
            reward -= fee
        elif action == 0 and self.position >= 0:
            self.position = -1
            reward -= fee
        elif action == 1:
            reward -= 0.00005

        if self.position == 1:
            reward += ret
        elif self.position == -1:
            reward -= ret

        reward -= abs(self.position) * self.cfg.risk_penalty * abs(ret)
        self.equity *= (1.0 + reward)
        self.pointer += 1
        if self.pointer >= min(len(self.df) - 2, self.cfg.max_steps):
            self.done = True
        return self.state(), float(reward), self.done, {"equity": self.equity}


def load_latest_dataset(dataset_dir: Path) -> pd.DataFrame:
    files = sorted(dataset_dir.glob("*"))
    if not files:
        raise FileNotFoundError(f"dataset_not_found:{dataset_dir}")
    latest = files[-1]
    if latest.suffix == ".parquet":
        return pd.read_parquet(latest)
    return pd.read_csv(latest)


def train_q_learning(df: pd.DataFrame, episodes: int = 200) -> dict[str, Any]:
    env = MarketEnv(df, TradeEnvConfig())
    actions = [0, 1, 2]
    q: dict[tuple[tuple[int, int, int], int], float] = {}
    alpha = 0.1
    gamma = 0.95
    epsilon = 1.0
    epsilon_min = 0.05
    epsilon_decay = 0.985
    best_equity = 0.0
    last_equity = 1.0

    def qv(state: tuple[int, int, int], action: int) -> float:
        return q.get((state, action), 0.0)

    for _ in range(episodes):
        state = env.reset()
        done = False
        while not done:
            if np.random.random() < epsilon:
                action = int(np.random.choice(actions))
            else:
                vals = [qv(state, a) for a in actions]
                action = int(actions[int(np.argmax(vals))])
            next_state, reward, done, info = env.step(action)
            target = reward + gamma * max(qv(next_state, a) for a in actions)
            q[(state, action)] = qv(state, action) + alpha * (target - qv(state, action))
            state = next_state
            last_equity = float(info.get("equity", last_equity))
            best_equity = max(best_equity, last_equity)
        epsilon = max(epsilon_min, epsilon * epsilon_decay)

    policy: dict[str, int] = {}
    for rsi in [0, 1, 2]:
        for macd in [0, 1, 2]:
            for vol in [0, 1, 2]:
                state = (rsi, macd, vol)
                vals = [qv(state, a) for a in actions]
                policy[str(state)] = int(actions[int(np.argmax(vals))])

    return {"best_equity": best_equity, "last_equity": last_equity, "episodes": episodes, "policy": policy}


def train_from_root(root: Path) -> dict[str, Any]:
    dataset_dir = root / "ai" / "data" / "datasets"
    models_dir = root / "ai" / "models"
    models_dir.mkdir(parents=True, exist_ok=True)
    df = load_latest_dataset(dataset_dir)
    result = train_q_learning(df, episodes=int(os.getenv("QAI_RL_EPISODES", "250")))
    out = models_dir / "rl_policy.json"
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    return {"ok": True, "policy": str(out), "best_equity": result["best_equity"], "last_equity": result["last_equity"]}


def main() -> None:
    root = Path(os.getenv("QAI_ROOT", Path(__file__).resolve().parents[2]))
    print(json.dumps(train_from_root(root), ensure_ascii=False))


if __name__ == "__main__":
    main()
