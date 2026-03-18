#!/usr/bin/env bash
set -Eeuo pipefail

PROJ_DIR="${PROJ_DIR:-$HOME/QuantumAI-Dockerized-System}"
APP_DIR="${APP_DIR:-$PROJ_DIR}"
VENV="$PROJ_DIR/.venv-host"

source "$VENV/bin/activate"

HOST_PORT="${HOST_PORT:-5002}"
CTR="${CTR:-gli-container}"
IMAGE="${IMAGE:-erenuludemir/gli-app:fixed}"

cd "$APP_DIR"

if [[ -f .env ]]; then
  perl -0777 -pe 's/^USDT_CONTRACT_ADDRESS=.*/USDT_CONTRACT_ADDRESS=0xE970e908cbc61123D067D54Da9A0d8Ff56DfcDBA/m' -i .env || true
fi

if [[ -f "$PROJ_DIR/requirements.lock" ]] && grep -q '^parsimonious==0\.10\.0$' "$PROJ_DIR/requirements.lock"; then
  cp -f "$PROJ_DIR/requirements.lock" "$PROJ_DIR/requirements.lock.bak.$(date +%Y%m%d_%H%M%S)"
  LC_ALL=C sed -i '' -E 's/^parsimonious==0\.10\.0$/parsimonious==0.9.0/' "$PROJ_DIR/requirements.lock"
fi

python -m pip install --only-binary=:all: \
  aiohttp==3.9.5 yarl==1.20.1 frozenlist==1.7.0 multidict==6.6.4 aiosignal==1.4.0

if python - <<'PY' >/dev/null 2>&1
import importlib.util, sys
sys.exit(0 if importlib.util.find_spec("lru") else 1)
PY
then
  :
else
  mkdir -p "$PROJ_DIR/_wheels"
  python -m pip wheel --no-build-isolation --no-cache-dir lru-dict==1.2.0 -w "$PROJ_DIR/_wheels" || true
  python -m pip install --no-index --find-links "$PROJ_DIR/_wheels" lru-dict==1.2.0 || echo "[WARN] lru-dict opsiyonel"
fi

if [[ -s "$PROJ_DIR/requirements.lock" ]]; then
  PIP_NO_BUILD_ISOLATION=1 python -m pip install --no-build-isolation --no-cache-dir -r "$PROJ_DIR/requirements.lock"
elif [[ -s "$PROJ_DIR/requirements.txt" ]]; then
  PIP_NO_BUILD_ISOLATION=1 python -m pip install --no-build-isolation --no-cache-dir -r "$PROJ_DIR/requirements.txt"
fi
