#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -d .venv ]]; then
  python3 -m venv .venv
  . .venv/bin/activate
  pip install -r requirements.txt gunicorn
else
  . .venv/bin/activate
fi
exec gunicorn app:create_app --chdir quantumai-usdt-v2 --bind 0.0.0.0:5002 --workers 2 --threads 4 --timeout 60
