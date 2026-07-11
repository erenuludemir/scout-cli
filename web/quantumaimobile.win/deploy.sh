#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="${PROJECT_NAME:-quantumaimobile-win}"
BRANCH_NAME="${BRANCH_NAME:-main}"
ACCOUNT_ID="${ACCOUNT_ID:-c3df6d40a60e5c69d1c94c8efeb0dd77}"

cd "$ROOT"

npx wrangler whoami >/dev/null
npx wrangler pages project create "$PROJECT_NAME" --production-branch "$BRANCH_NAME" --compatibility-date "2026-04-12" >/dev/null 2>&1 || true
npx wrangler pages deploy public --project-name "$PROJECT_NAME" --branch "$BRANCH_NAME" --commit-dirty=true
npx wrangler pages deployment list --project-name "$PROJECT_NAME"
printf '\nDashboard: https://dash.cloudflare.com/%s/pages/view/%s\n' "$ACCOUNT_ID" "$PROJECT_NAME"
