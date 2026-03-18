# Quantum AI Training And Grid Module

## Kurulum

```bash
cd "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
python3 -m venv .venv
source .venv/bin/activate
pip install -r quantum_ai_trading/requirements-ai-trading.txt
```

## Egitim

```bash
cd "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
source .venv/bin/activate
python quantum_ai_trading/train_bot_models.py
```

## Sinyal

```bash
cd "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
source .venv/bin/activate
python quantum_ai_trading/generate_signal.py
```

## Grid Plan

```bash
cd "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
source .venv/bin/activate
python quantum_ai_trading/generate_grid_plan.py 2500
```

## FastAPI Router Entegrasyonu

```python
from quantum_ai_trading.api_routes_ai_trading import router as quantum_ai_router

app.include_router(quantum_ai_router)
```
