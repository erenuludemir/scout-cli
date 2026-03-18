from __future__ import annotations

import numpy as np
import pandas as pd

from .datasets import FEATURE_COLUMNS


class TradingRLEnv:
    def __init__(self, df: pd.DataFrame, fee_bps: float = 5.0):
        self.df = df.reset_index(drop=True)
        self.fee_bps = fee_bps / 10000.0
        self.ptr = 0
        self.position = 0
        self.entry_price = 0.0

    def reset(self) -> np.ndarray:
        self.ptr = 0
        self.position = 0
        self.entry_price = 0.0
        return self.state()

    def state(self) -> np.ndarray:
        row = self.df.iloc[self.ptr]
        return np.array([float(row[col]) for col in FEATURE_COLUMNS], dtype=np.float32)

    def step(self, action: int) -> tuple[np.ndarray, float, bool, dict]:
        row = self.df.iloc[self.ptr]
        current_price = float(row["close"])
        reward = 0.0
        info = {"position": self.position}

        if action != self.position:
            reward -= self.fee_bps
            self.position = action
            self.entry_price = current_price

        next_ptr = min(self.ptr + 1, len(self.df) - 1)
        next_price = float(self.df.iloc[next_ptr]["close"])
        price_return = (next_price / current_price) - 1.0

        if self.position == 1:
            reward += price_return
        elif self.position == -1:
            reward -= price_return

        self.ptr = next_ptr
        done = self.ptr >= len(self.df) - 1
        return self.state(), float(reward), done, info
