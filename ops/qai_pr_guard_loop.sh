#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
LOG_DIR="$REPO/_logs/pr_guard"
STATE_DIR="$REPO/_state/pr_guard"
mkdir -p "$LOG_DIR" "$STATE_DIR"

TS="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$LOG_DIR/$TS.run.log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "PR_GUARD_START=$TS"
date
echo "PWD=$REPO"

cd "$REPO" || exit 1

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

for bin in git gh ssh python3; do
  command -v "$bin" >/dev/null 2>&1 || { echo "BIN_YOK:$bin"; exit 1; }
done

chmod +x "$REPO/.githooks/pre-push" "$REPO/ops/qai_dependency_audit.sh" 2>/dev/null || true
git config core.hooksPath .githooks
git remote set-url origin git@github.com:erenuludemir/scout-cli.git

if ! /usr/bin/ssh -o BatchMode=yes -T git@github.com >/tmp/qai_ssh_test.out 2>&1; then
  if ! grep -q "successfully authenticated" /tmp/qai_ssh_test.out; then
    echo "SSH_GITHUB_ERISIM_YOK"
    cat /tmp/qai_ssh_test.out || true
    exit 0
  fi
fi

gh auth status >/dev/null 2>&1 || {
  echo "GH_LOGIN_GEREKLI"
  exit 0
}

gh auth setup-git >/dev/null 2>&1 || true

CURRENT_BRANCH="$(git branch --show-current)"
[ -n "$CURRENT_BRANCH" ] || { echo "BRANCH_YOK"; exit 1; }

OWNER="$(gh repo view --json owner -q .owner.login 2>/dev/null || true)"
REPO_NAME="$(gh repo view --json name -q .name 2>/dev/null || true)"
DEFAULT_BRANCH="$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || true)"
[ -n "$OWNER" ] && [ -n "$REPO_NAME" ] && [ -n "$DEFAULT_BRANCH" ] || { echo "REPO_BILGISI_COZULEMEDI"; exit 1; }

echo "OWNER=$OWNER"
echo "REPO_NAME=$REPO_NAME"
echo "DEFAULT_BRANCH=$DEFAULT_BRANCH"
echo "CURRENT_BRANCH=$CURRENT_BRANCH"

if [ "$CURRENT_BRANCH" = "$DEFAULT_BRANCH" ]; then
  echo "DEFAULT_BRANCH_UZERINDESIN_PR_ACILMAYACAK"
else
  git fetch origin --prune || true
  git push --set-upstream origin "$CURRENT_BRANCH"

  PR_NUMBER="$(gh pr list --head "$CURRENT_BRANCH" --base "$DEFAULT_BRANCH" --state open --json number -q '.[0].number' 2>/dev/null || true)"

  if [ -z "${PR_NUMBER:-}" ]; then
    PR_TITLE="auto: ${CURRENT_BRANCH} -> ${DEFAULT_BRANCH}"
    PR_BODY=$'Otomatik PR guard tarafindan olusturuldu.\n\n- make audit\n- branch protection verify\n- auto merge denemesi'
    gh pr create --base "$DEFAULT_BRANCH" --head "$CURRENT_BRANCH" --title "$PR_TITLE" --body "$PR_BODY"
    PR_NUMBER="$(gh pr list --head "$CURRENT_BRANCH" --base "$DEFAULT_BRANCH" --state open --json number -q '.[0].number' 2>/dev/null || true)"
    echo "PR_CREATED=$PR_NUMBER"
  else
    echo "PR_EXISTS=$PR_NUMBER"
  fi

  if [ -n "${PR_NUMBER:-}" ]; then
    gh pr view "$PR_NUMBER" --json number,state,isDraft,mergeable,headRefName,baseRefName,statusCheckRollup 2>/dev/null > "$STATE_DIR/pr_${PR_NUMBER}.json" || true
    gh pr merge "$PR_NUMBER" --auto --squash --delete-branch=false >/dev/null 2>&1 || true
    echo "PR_AUTO_MERGE_REQUESTED=$PR_NUMBER"
  fi
fi

make audit

gh api -H "Accept: application/vnd.github+json" "/repos/$OWNER/$REPO_NAME/branches/$DEFAULT_BRANCH/protection" > "$STATE_DIR/branch_protection_${DEFAULT_BRANCH}.json"

python3 - "$STATE_DIR/branch_protection_${DEFAULT_BRANCH}.json" <<'PY'
import json,sys
p=sys.argv[1]
data=json.load(open(p,"r",encoding="utf-8"))
strict=((data.get("required_status_checks") or {}).get("strict"))
contexts=((data.get("required_status_checks") or {}).get("contexts") or [])
reviews=((data.get("required_pull_request_reviews") or {}).get("required_approving_review_count"))
linear=bool(data.get("required_linear_history",{}).get("enabled",False))
conv=bool(data.get("required_conversation_resolution",{}).get("enabled",False))
admins=bool(data.get("enforce_admins",{}).get("enabled",False))
ok = strict is True and "audit" in contexts and linear and conv and admins and (reviews or 0) >= 1
print(f"BP_STRICT={strict}")
print(f"BP_CONTEXTS={','.join(contexts)}")
print(f"BP_REVIEWS={reviews}")
print(f"BP_LINEAR={linear}")
print(f"BP_CONVERSATION={conv}")
print(f"BP_ADMINS={admins}")
print("BRANCH_PROTECTION_OK" if ok else "BRANCH_PROTECTION_DRIFT")
sys.exit(0 if ok else 2)
PY

echo "PR_GUARD_DONE=$TS"
