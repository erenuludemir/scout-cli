#!/bin/bash
set -Eeuo pipefail

export LANG=C LC_ALL=C
APP_DIR="$HOME/QuantumAI-Dockerized-System"
VENV_DIR="$APP_DIR/.venv"
DMG_URL="https://desktop.docker.com/mac/main/arm64/Docker.dmg"
DMG_LOCAL="$APP_DIR/Docker.dmg"
REQUIREMENTS_FILE="$APP_DIR/requirements.txt"
PLIST_DIR="$HOME/Library/LaunchAgents"
LAUNCHER_PLIST="$PLIST_DIR/com.qai.boot.plist"
PY_VERSION="3.11"

mkdir -p "$APP_DIR" "$PLIST_DIR"
cd "$APP_DIR"

if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
fi

if [[ "$(uname -m)" == "arm64" ]]; then
  /usr/sbin/softwareupdate --install-rosetta --agree-to-license || true
fi

if ! command -v brew >/dev/null; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

brew install python@$PY_VERSION pipx docker docker-compose git curl jq coreutils

curl -L "$DMG_URL" -o "$DMG_LOCAL"
hdiutil attach "$DMG_LOCAL" -mountpoint /Volumes/Docker
cp -R "/Volumes/Docker/Docker.app" /Applications/
hdiutil detach /Volumes/Docker

open -a Docker

echo "[*] Docker balatlyor..."
until docker system info >/dev/null 2>&1; do sleep 2; done

python$PY_VERSION -m venv "$VENV_DIR"
source "$VENV_DIR/bin/activate"

pip install --upgrade pip setuptools wheel
curl -sSL https://raw.githubusercontent.com/erenuludemir/quantumai-deps/main/requirements-full.txt -o "$REQUIREMENTS_FILE"
pip install -r "$REQUIREMENTS_FILE"

cat > "$LAUNCHER_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.qai.boot</string>
    <key>ProgramArguments</key>
    <array>
        <string>$VENV_DIR/bin/python</string>
        <string>$APP_DIR/main.py</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

launchctl unload "$LAUNCHER_PLIST" 2>/dev/null || true
launchctl load "$LAUNCHER_PLIST"

echo "[] QuantumAI ortam Docker Desktop ile balatld."
echo "[] .venv aktif. requirements.txt yklendi."
echo "[] Docker + CLI + Python + LLM modlleri uyumlu."

echo "[] Sistem tamamland. Terminal: source $VENV_DIR/bin/activate"

