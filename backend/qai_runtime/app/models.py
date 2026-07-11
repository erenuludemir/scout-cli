from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field


class OrderSide(str, Enum):
    buy = "BUY"
    sell = "SELL"


class OrderPayload(BaseModel):
    id: str = Field(min_length=3, max_length=128)
    symbol: str = Field(min_length=3, max_length=32)
    side: OrderSide
    price: float = Field(gt=0)
    amount: float = Field(gt=0)
    timestamp: float


class CommandPayload(BaseModel):
    command: str = Field(min_length=3, max_length=64)


class HealthResponse(BaseModel):
    status: str
    service: str
    timestamp: datetime
    checks: dict[str, str]
