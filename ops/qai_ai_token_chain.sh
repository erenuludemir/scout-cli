#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -n "${QAI_PYTHON:-}" ]; then
  PYTHON_BIN="${QAI_PYTHON}"
elif [ -x "$ROOT/.venv_qai_ai/bin/python" ]; then
  PYTHON_BIN="$ROOT/.venv_qai_ai/bin/python"
else
  PYTHON_BIN="python3"
fi

run_step() {
  local label="$1"
  shift
  printf 'STEP:%s\n' "$label"
  "$@"
  printf '\n'
}

run_step "ai_dataset" "$PYTHON_BIN" "$ROOT/ai/data/market_data_pipeline.py"
run_step "ai_train_supervised" "$PYTHON_BIN" "$ROOT/ai/training/supervised_trainer.py"
run_step "ai_train_rl" "$PYTHON_BIN" "$ROOT/ai/training/reinforcement_trainer.py"
run_step "ai_signal" "$PYTHON_BIN" "$ROOT/ai/signals/signal_engine.py"
run_step "ai_grid" "$PYTHON_BIN" "$ROOT/ai/strategies/grid_leverage_engine.py"
run_step "token_compile_erc20" env TOKEN_CHAIN_TYPE=erc20 "$PYTHON_BIN" -m token_factory.scripts.compile_token
run_step "token_compile_trc20" env TOKEN_CHAIN_TYPE=trc20 "$PYTHON_BIN" -m token_factory.scripts.compile_token

if [ "${LINEAR_AUTO_CREATE_ISSUE:-0}" = "1" ] && [ -n "${LINEAR_API_KEY:-}" ]; then
  run_step "linear_signal_issue" "$PYTHON_BIN" "$ROOT/ai/signals/push_signal_to_linear.py"
else
  printf 'STEP:%s\n' "linear_signal_issue"
  printf '%s\n\n' '{"ok":true,"skipped":true,"reason":"LINEAR_AUTO_CREATE_ISSUE disabled or LINEAR_API_KEY missing"}'
fi
