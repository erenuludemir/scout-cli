#!/usr/bin/env bash
set -euo pipefail
echo "[INFO] This script prints guidance; it does not perform rotation automatically." 
echo "Steps:" 
cat <<'GUIDE'
1. Enumerate suspected leaked keys (grep -R "API_KEY=" -n .env* .env.example).
2. In each provider dashboard, create new keys; store securely (1Password/Vault).
3. Update local .env (never commit real secrets).
4. (Optional) Purge old secrets from git history:
   a. Create replacements.txt mapping oldKey==>REDACTED
   b. pip install git-filter-repo
   c. git filter-repo --replace-text replacements.txt
   d. git push --force origin main
5. Invalidate old keys (revoke/delete in provider portal).
6. Add pre-commit detect-secrets:
   detect-secrets scan > .secrets.baseline
   pre-commit install
GUIDE
echo "Done." 