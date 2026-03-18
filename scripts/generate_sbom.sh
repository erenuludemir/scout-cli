#!/usr/bin/env bash
set -euo pipefail

IMAGE="${1:-quantumai-usdt-v2:latest}"
OUT="${2:-sbom-${IMAGE//[:\/]/_}.spdx.json}"

if ! command -v syft >/dev/null 2>&1; then
  echo "syft not installed. Install via: curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin" >&2
  exit 2
fi

echo "[sbom] Generating SBOM for image: $IMAGE -> $OUT"
syft packages "$IMAGE" -o spdx-json > "$OUT"
echo "[sbom] Done: $OUT"
