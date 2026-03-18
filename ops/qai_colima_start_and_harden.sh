#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${COLIMA_PROFILE:-mcai-colima}"
CPU="${COLIMA_CPU:-4}"
MEMORY="${COLIMA_MEMORY:-8}"
DISK="${COLIMA_DISK:-80}"
ARCH="${COLIMA_ARCH:-aarch64}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "MISSING:$1" >&2
    exit 1
  }
}

need colima
need docker
need bash

if ! colima status -p "$PROFILE" >/dev/null 2>&1; then
  colima start -p "$PROFILE" --arch "$ARCH" --cpu "$CPU" --memory "$MEMORY" --disk "$DISK" --vm-type=vz --mount-type=virtiofs
fi

export DOCKER_HOST="unix://$HOME/.colima/${PROFILE}/docker.sock"

bash "$ROOT/ops/qai_colima_sysctl.sh"

docker version >/dev/null
docker info >/dev/null

printf 'COLIMA_PROFILE=%s\n' "$PROFILE"
printf 'DOCKER_HOST=%s\n' "$DOCKER_HOST"
