# Quantum AI Token Factory

## Kurulum

```bash
cd "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
python3 -m venv .venv
source .venv/bin/activate
pip install -r token_factory/requirements-token-factory.txt
cp .env.token_factory.example .env.token_factory
```

## ERC-20 Derleme

```bash
cd "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
source .venv/bin/activate
export TOKEN_CHAIN_TYPE=erc20
python -m token_factory.scripts.compile_token
```

## ERC-20 Deploy

```bash
cd "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
source .venv/bin/activate
export TOKEN_CHAIN_TYPE=erc20
python -m token_factory.scripts.deploy_erc20
```

## ERC-20 Dagitim

```bash
cd "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
source .venv/bin/activate
export TOKEN_CHAIN_TYPE=erc20
export TOKEN_DISTRIBUTION_CSV="$PWD/token_factory/distributions/example.csv"
python -m token_factory.scripts.distribute_erc20
```

## TRC-20 Derleme

```bash
cd "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
source .venv/bin/activate
export TOKEN_CHAIN_TYPE=trc20
python -m token_factory.scripts.compile_token
```

## TRC-20 Deploy

```bash
cd "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
source .venv/bin/activate
export TOKEN_CHAIN_TYPE=trc20
python -m token_factory.scripts.deploy_trc20
```

## TRC-20 Dagitim

```bash
cd "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
source .venv/bin/activate
export TOKEN_CHAIN_TYPE=trc20
export TOKEN_DISTRIBUTION_CSV="$PWD/token_factory/distributions/example.csv"
python -m token_factory.scripts.distribute_trc20
```

## Durum Dogrulama

```bash
cd "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
source .venv/bin/activate
python -m token_factory.scripts.verify_local_contract_state
```
