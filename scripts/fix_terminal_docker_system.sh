/usr/bin/env bash <<'FIX'
set -Eeuo pipefail
export LANG=C LC_ALL=C
ts="$(date +%Y%m%d_%H%M%S)"
for f in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.zlogin" "$HOME/.zshenv"; do
  [[ -f "$f" ]] && cp -p "$f" "$f.bak.$ts"
done
cat > "$HOME/.zshrc" <<'ZRC'
export LANG=C LC_ALL=C
if command -v /opt/homebrew/bin/brew >/dev/null 2>&1; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
export PATH="$HOME/bin:$HOME/.local/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
ulimit -n 10240 2>/dev/null || true
ulimit -u 2048  2>/dev/null || true
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
ZRC
if command -v tmux >/dev/null 2>&1; then
  tmux kill-server >/dev/null 2>&1 || true
fi
rm -rf /tmp/tmux-$(id -u)/* 2>/dev/null || true
dscl . -read /Users/"$USER" UserShell >/dev/null 2>&1 || true
if command -v chsh >/dev/null 2>&1; then
  if [[ "${SHELL:-}" != "/bin/zsh" && -x /bin/zsh ]]; then chsh -s /bin/zsh "$USER" || true; fi
fi
if command -v /opt/homebrew/bin/brew >/dev/null 2>&1; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
command -v colima >/dev/null 2>&1 || brew install colima >/dev/null 2>&1 || true
command -v docker >/dev/null 2>&1 || brew install docker >/dev/null 2>&1 || true
# Start Colima Docker and set DOCKER_HOST
if command -v colima >/dev/null 2>&1; then
  export COLIMA_HOME="${COLIMA_HOME:-$HOME/.colima}"
  colima stop default >/dev/null 2>&1 || true
  colima start default --runtime docker --arch aarch64 --cpu 4 --memory 6 --disk 60 --network-address >/dev/null 2>&1 || colima start --runtime docker >/dev/null 2>&1 || true
  export DOCKER_HOST="unix://$COLIMA_HOME/default/docker.sock"
  for _ in $(seq 1 30); do
    [[ -S "$COLIMA_HOME/default/docker.sock" ]] && break || sleep 1
  done
fi
DOCKER_OK=0
if command -v docker >/dev/null 2>&1; then
  docker info >/dev/null 2>&1 && DOCKER_OK=1 || DOCKER_OK=0
fi
if command -v tmux >/dev/null 2>&1; then
  tmux new -d -s healthcheck "sleep 1" >/dev/null 2>&1 || true
  tmux kill-session -t healthcheck >/dev/null 2>&1 || true
fi
APP_DIR="${APP_DIR:-$HOME/QuantumAI-Dockerized-System}"
SCRIPTS_DIR="$APP_DIR/scripts"
if [[ -d "$APP_DIR" ]]; then
  mkdir -p "$SCRIPTS_DIR"
  /usr/bin/python3 -m venv "$APP_DIR/.venv-host" >/dev/null 2>&1 || true
  source "$APP_DIR/.venv-host/bin/activate"
  python - <<'PY' || true
import sys; print("Python OK:",sys.version.split()[0])
PY
  deactivate || true
fi
echo "===RUN_THESE_NEXT==="
echo "exec zsh -l"
if [[ "$DOCKER_OK" -ne 1 ]]; then
  echo "# docker still unavailable -> check colima logs: colima status && colima ls && colima nerdctl ps"
else
  echo "docker version"
fi
echo "tmux"
FIX
