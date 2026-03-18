#!/usr/bin/env bash
set -euo pipefail

# One-step helper: build v2, start minimal stack (redis + v2 + gateway), verify health,
# optionally purge legacy spaced directory, and remind about enabling strict vuln scans.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

PURGE=0
STRICT=0
SILENT=0
MULTIARCH=0

usage() {
  cat <<USG
Usage: $0 [--purge] [--strict] [--silent] [--multiarch]

Steps performed:
  1. Verify docker daemon available.
  2. Run: make build-v2 (or multi-arch build if --multiarch)
  3. Run: make up-core (redis + quantumai-usdt-v2 + gateway)
  4. Health check v2: http://localhost:5005/health (fallback /)
  5. Health check gateway: http://localhost:5003/health
  6. (Optional --purge) git rm -r " quantumai-usdt-v2" legacy directory if health OK.
  7. (Optional --strict) Print instruction to set VULN_STRICT=true in CI.

Flags:
  --purge   Remove legacy spaced directory after successful health checks.
  --strict  Emit instructions for enabling failing vulnerability scans in CI.
  --multiarch       Perform a local multi-arch build (Buildx) instead of normal build.
  --silent          Reduce curl output (only exit code relevant).
  -h|--help Show this help.

Environment:
  TIMEOUT_SECS (default 40) – total wait per health endpoint.

Examples:
  $0                # Just build & verify
  $0 --purge        # Build, verify, then remove legacy dir
  $0 --purge --strict
USG
}

for arg in "$@"; do
  case "$arg" in
    --purge) PURGE=1 ;;
    --strict) STRICT=1 ;;
  --silent) SILENT=1 ;;
  --multiarch) MULTIARCH=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $arg" >&2; usage; exit 1 ;;
  esac
done

echo "[one-step] ➜ Checking docker daemon"
if ! docker info >/dev/null 2>&1; then
  echo "[one-step] ❌ Docker daemon not reachable. Start Docker and retry." >&2
  exit 2
fi

echo "[one-step] ➜ Building v2 image (${MULTIARCH:+multi-arch mode})"
if [ $MULTIARCH -eq 1 ]; then
  if ! docker buildx ls >/dev/null 2>&1; then
    echo "[one-step] ➜ Creating default buildx builder"
    docker buildx create --use --name multiarch-builder || true
  fi
  docker buildx build --platform linux/amd64,linux/arm64 -t quantumai-usdt-v2:local-multiarch --load quantumai-usdt-v2
else
  make build-v2
fi

echo "[one-step] ➜ Starting minimal stack (redis + v2 + gateway)"
make up-core

TIMEOUT_SECS=${TIMEOUT_SECS:-40}
deadline=$(( $(date +%s) + TIMEOUT_SECS ))

curl_flags=(-fsS)
[[ $SILENT -eq 1 ]] && curl_flags=(-fsS -o /dev/null)

echo -n "[one-step] ▹ Waiting for v2 health"
until curl "${curl_flags[@]}" http://localhost:5005/health || curl "${curl_flags[@]}" http://localhost:5005/; do
  if (( $(date +%s) > deadline )); then echo "\n[one-step] ❌ v2 health timed out"; exit 3; fi
  printf '.'; sleep 2
done
echo " ✓"

echo -n "[one-step] ▹ Waiting for gateway health"
until curl "${curl_flags[@]}" http://localhost:5003/health; do
  if (( $(date +%s) > deadline )); then echo "\n[one-step] ❌ gateway health timed out"; exit 4; fi
  printf '.'; sleep 2
done
echo " ✓"

LEGACY_DIR=" quantumai-usdt-v2"
if [[ $PURGE -eq 1 ]]; then
  if [[ -d "$LEGACY_DIR" ]]; then
    echo "[one-step] ➜ Purging legacy directory: '$LEGACY_DIR'"
    git rm -r "$LEGACY_DIR"
    echo "[one-step] ✓ Removed. Commit these changes (git commit -m 'chore: remove legacy spaced v2 directory')."
  else
    echo "[one-step] ℹ️ Legacy directory already absent."
  fi
else
  echo "[one-step] ℹ️ Skipping legacy purge (use --purge to remove)."
fi

if [[ $STRICT -eq 1 ]]; then
  cat <<STRICT_NOTE
[one-step] 🔒 Enable strict vulnerability scanning:
  1. Edit .github/workflows/ci.yml or set repository environment variable VULN_STRICT=true
  2. Re-run CI to enforce failing builds on HIGH/CRITICAL findings.
STRICT_NOTE
fi

echo "[one-step] ✅ Completed."
