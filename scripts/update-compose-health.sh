#!/usr/bin/env bash
set -euo pipefail

yq -i '.services["gli-container"].healthcheck = {
  "test": ["CMD", "curl", "-f", "http://127.0.0.1:5002/ || exit 1"],
  "interval": "20s",
  "timeout": "5s",
  "retries": 5
}' docker-compose.yml
