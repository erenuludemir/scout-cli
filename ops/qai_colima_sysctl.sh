#!/usr/bin/env bash
set -euo pipefail

PROFILE="${COLIMA_PROFILE:-mcai-colima}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "MISSING:$1" >&2
    exit 1
  }
}

need colima

if ! colima status -p "$PROFILE" >/dev/null 2>&1; then
  echo "COLIMA_PROFILE_NOT_RUNNING:$PROFILE" >&2
  exit 1
fi

colima ssh -p "$PROFILE" <<'SH'
set -euo pipefail

sudo mkdir -p /etc/sysctl.d

cat <<'CONF' | sudo tee /etc/sysctl.d/99-quantumai-redis.conf >/dev/null
vm.overcommit_memory=1
net.core.somaxconn=1024
CONF

sudo sysctl -w vm.overcommit_memory=1
sudo sysctl -w net.core.somaxconn=1024
sudo sysctl --system >/dev/null 2>&1 || true

printf 'vm.overcommit_memory='
cat /proc/sys/vm/overcommit_memory
printf 'net.core.somaxconn='
cat /proc/sys/net/core/somaxconn
SH
