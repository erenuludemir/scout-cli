PYTHON ?= python
QAI_PYTHON ?= $(shell [ -x ./.venv_qai_ai/bin/python ] && echo ./.venv_qai_ai/bin/python || echo $(PYTHON))
POETRY ?= poetry
DEFAULT_ETHERSCAN_ADDRESS ?= 0x71c7656ec7ab88b098defb751b7401b5f6d8976f
DEFAULT_ETHERSCAN_CHAINID ?= 1
DEFAULT_ETHERSCAN_CONTRACT ?= 0xdAC17F958D2ee523a2206206994597C13D831ec7
DEFAULT_ETHERSCAN_CONTRACTS ?= 0xdac17f958d2ee523a2206206994597c13d831ec7,0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48

.PHONY: help venv install dev test lint format build clean compose-up compose-down build-v2 buildx-v2 up-core health-v2 strict-vuln run-v2 purge-legacy-v2 balance-check balance-txlist balance-tokentx balance-portfolio balance-portfolio-fallback profit-scan ai-train ai-signal ai-grid-plan smoke-live logs-inside token-compile token-deploy token-distribute token-verify token-smoke ai-market-data ai-train-supervised ai-train-rl ai-signal-latest ai-grid-live ai-token-chain ai-api-run token-api-run linear-smoke linear-signal-issue

help: ## Show targets
	@grep -E '^[a-zA-Z0-9._-]+:.*?##' Makefile | awk -F':|##' '{printf "\033[36m%-26s\033[0m %s\n",$$1,$$3}' | sort

venv: ## Create virtual environment
	$(PYTHON) -m venv .venv
	. .venv/bin/activate && pip install --upgrade pip

install: ## Install runtime deps
	. .venv/bin/activate && pip install -r requirements.txt

dev: ## Install dev deps
	. .venv/bin/activate && pip install -r requirements-dev.txt

test: ## Run tests
	. .venv/bin/activate && pytest

lint: ## Basic lint
	. .venv/bin/activate && ruff check . || echo "(ruff not installed)"

build: ## Build docker images
	docker compose build

build-v2: ## Build only quantumai-usdt-v2 image
	docker compose build quantumai-usdt-v2

buildx-v2: ## Multi-arch build for quantumai-usdt-v2
	docker buildx build --platform linux/amd64,linux/arm64 -t quantumai-usdt-v2:multiarch --load quantumai-usdt-v2

up-core: ## Start redis, v2, and gateway only
	docker compose up -d redis quantumai-usdt-v2 gateway

health-v2: ## Curl v2 health endpoint
	curl -fsS http://localhost:5005/health || curl -fsS http://localhost:5005/ || echo 'health check failed'

strict-vuln: ## Explain strict vulnerability env
	echo 'Set VULN_STRICT=true in GitHub Actions workflow or repository env to enforce failing builds on HIGH/CRITICAL'

run-v2: ## Run quantumai-usdt-v2 locally via gunicorn
	. .venv/bin/activate && gunicorn app:create_app --chdir quantumai-usdt-v2 --bind 0.0.0.0:5002 --workers 2 --threads 4 --timeout 60

compose-up: ## Start stack
	docker compose up -d

compose-down: ## Stop stack
	docker compose down

clean: ## Remove caches and bytecode
	rm -rf .pytest_cache .coverage coverage.xml **/__pycache__

purge-legacy-v2: ## Remove legacy spaced directory after validation
	@if [ -d " quantumai-usdt-v2" ]; then git rm -r " quantumai-usdt-v2"; else echo 'Legacy directory not present'; fi

balance-check: ## Native ETH balance check ADDRESS=0x... CHAINID=1
	./run.sh balance-check "$(or $(ADDRESS),$(DEFAULT_ETHERSCAN_ADDRESS))" "$(or $(CHAINID),$(DEFAULT_ETHERSCAN_CHAINID))"

balance-txlist: ## Native tx list ADDRESS=0x... CHAINID=1 PAGE=1 OFFSET=10 SORT=desc
	./run.sh balance-txlist "$(or $(ADDRESS),$(DEFAULT_ETHERSCAN_ADDRESS))" "$(or $(CHAINID),$(DEFAULT_ETHERSCAN_CHAINID))" "$(or $(PAGE),1)" "$(or $(OFFSET),10)" "$(or $(SORT),desc)"

balance-tokentx: ## ERC20 tx list ADDRESS=0x... CHAINID=1 CONTRACT=0x... PAGE=1 OFFSET=10 SORT=desc
	./run.sh balance-tokentx "$(or $(ADDRESS),$(DEFAULT_ETHERSCAN_ADDRESS))" "$(or $(CHAINID),$(DEFAULT_ETHERSCAN_CHAINID))" "$(or $(CONTRACT),$(DEFAULT_ETHERSCAN_CONTRACT))" "$(or $(PAGE),1)" "$(or $(OFFSET),10)" "$(or $(SORT),desc)"

balance-portfolio: ## Portfolio endpoint with fallback ADDRESS=0x... CHAINID=1 CONTRACTS=0x...,0x...
	./run.sh balance-portfolio "$(or $(ADDRESS),$(DEFAULT_ETHERSCAN_ADDRESS))" "$(or $(CHAINID),$(DEFAULT_ETHERSCAN_CHAINID))" "$(CONTRACTS)"

balance-portfolio-fallback: ## Read-only fallback portfolio ADDRESS=0x... CHAINID=1 CONTRACTS=0x...,0x...
	./run.sh balance-portfolio-fallback "$(or $(ADDRESS),$(DEFAULT_ETHERSCAN_ADDRESS))" "$(or $(CHAINID),$(DEFAULT_ETHERSCAN_CHAINID))" "$(or $(CONTRACTS),$(DEFAULT_ETHERSCAN_CONTRACTS))"

profit-scan: ## Preview profit scan FROM=USDT TO=ETH AMOUNTS=100,250,500 TARGET_EDGE_BPS=120 MIN_PROFIT_USD=5
	./run.sh profit-scan "$(or $(FROM),USDT)" "$(or $(TO),ETH)" "$(or $(AMOUNTS),100,250,500,1000)" "$(or $(TARGET_EDGE_BPS),120)" "$(or $(MIN_PROFIT_USD),5)" "$(or $(SLIPPAGE_BPS),50)" "$(or $(GATEWAY_URL),http://127.0.0.1:5003)"

ai-train: ## Train Quantum AI market models
	$(PYTHON) quantum_ai_trading/train_bot_models.py

ai-signal: ## Generate Quantum AI paper signal
	$(PYTHON) quantum_ai_trading/generate_signal.py

ai-grid-plan: ## Generate Quantum AI grid plan CAPITAL=2500
	$(PYTHON) quantum_ai_trading/generate_grid_plan.py "$(or $(CAPITAL),1000)"

smoke-live: ## Run live endpoint smoke checks for master/main/base stacks
	bash ops/qai_endpoint_smoke.sh

logs-inside: ## Show container log files SERVICE=gateway|dex|usdt|usdt-v2|gli|gli-mainnet|gli-sepolia
	bash ops/qai_inside_logs.sh "$(or $(SERVICE),all)"

token-compile: ## Compile token factory contract TOKEN_CHAIN_TYPE=erc20|trc20
	$(PYTHON) -m token_factory.scripts.compile_token

token-deploy: ## Deploy token factory contract TOKEN_CHAIN_TYPE=erc20|trc20
	@if [ "$(TOKEN_CHAIN_TYPE)" = "trc20" ]; then \
		$(PYTHON) -m token_factory.scripts.deploy_trc20; \
	else \
		$(PYTHON) -m token_factory.scripts.deploy_erc20; \
	fi

token-distribute: ## Distribute token factory supply TOKEN_CHAIN_TYPE=erc20|trc20 TOKEN_DISTRIBUTION_CSV=/abs/path.csv
	@if [ "$(TOKEN_CHAIN_TYPE)" = "trc20" ]; then \
		$(PYTHON) -m token_factory.scripts.distribute_trc20; \
	else \
		$(PYTHON) -m token_factory.scripts.distribute_erc20; \
	fi

token-verify: ## Verify deployed token state TOKEN_CHAIN_TYPE=erc20|trc20
	$(PYTHON) -m token_factory.scripts.verify_local_contract_state

token-smoke: ## Run token factory unit tests
	$(PYTHON) -m pytest -q tests/test_token_factory.py

ai-market-data: ## Build AI market dataset QAI_SYMBOL=BTCUSDT QAI_INTERVAL=1h QAI_LIMIT=1200
	$(QAI_PYTHON) ai/data/market_data_pipeline.py

ai-train-supervised: ## Train AI supervised model
	$(QAI_PYTHON) ai/training/supervised_trainer.py

ai-train-rl: ## Train AI reinforcement policy
	$(QAI_PYTHON) ai/training/reinforcement_trainer.py

ai-signal-latest: ## Generate latest AI signal
	$(QAI_PYTHON) ai/signals/signal_engine.py

ai-grid-live: ## Generate AI grid/leverage plan
	$(QAI_PYTHON) ai/strategies/grid_leverage_engine.py

ai-token-chain: ## Run integrated AI+token compile chain
	QAI_PYTHON="$(QAI_PYTHON)" bash ops/qai_ai_token_chain.sh

ai-api-run: ## Run AI FastAPI on :8010
	QAI_PYTHON="$(QAI_PYTHON)" $(QAI_PYTHON) -m uvicorn ai.api.ai_bot_api:app --host 0.0.0.0 --port 8010

token-api-run: ## Run token factory FastAPI on :8011
	QAI_PYTHON="$(QAI_PYTHON)" $(QAI_PYTHON) -m uvicorn token_factory.api.token_factory_api:app --host 0.0.0.0 --port 8011

linear-smoke: ## Smoke test Linear connectivity if LINEAR_API_KEY is set
	QAI_PYTHON="$(QAI_PYTHON)" bash ops/qai_linear_smoke.sh

linear-signal-issue: ## Push latest AI signal to Linear as issue
	QAI_PYTHON="$(QAI_PYTHON)" $(QAI_PYTHON) ai/signals/push_signal_to_linear.py
