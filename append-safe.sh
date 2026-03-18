#!/usr/bin/env bash
set -euo pipefail

ICLOUD_ROOT="/Users/erenuludemir/Library/Mobile Documents/com~apple~CloudDocs"
QAI_PANEL="$ICLOUD_ROOT/QuantumAI-Blockchain-Panel"
QAI_DOCKER="$HOME/QuantumAI-Dockerized-System"
PCI_SCRIPTS="/Users/erenuludemir/pci_admin_paneli/scripts"
LAUNCHAGENTS="$HOME/Library/LaunchAgents"

mkdir -p "$QAI_DOCKER"/{apps,logs,scripts,ops} "$LAUNCHAGENTS" "$PCI_SCRIPTS"

if [ ! -f "$QAI_DOCKER/.env" ]; then
  cat > "$QAI_DOCKER/.env" <<'ENV'
# QuantumAI Dockerized System – runtime secrets/template
# production'da gerçek değerlerle doldurun.
API_KEY="changeme"
REDIS_URL="redis://localhost:6379/0"
WS_PORT="8765"
API_PORT="8000"
LOG_LEVEL="INFO"
ENV
  echo "[+] created: $QAI_DOCKER/.env"
fi

if [ ! -f "$QAI_DOCKER/docker-compose.yml" ]; then
  cat > "$QAI_DOCKER/docker-compose.yml" <<'YML'
services:
  quantumai-usdt:
    image: quantumai-usdt.apps:latest
    container_name: quantumai-usdt
    restart: unless-stopped
    environment:
      - TZ=Europe/Istanbul
      - PYTHONUNBUFFERED=1
      - LOG_LEVEL=${LOG_LEVEL:-INFO}
      - QAI_ENV_FILE=/run/secrets/qai_env
    secrets:
      - qai_env
    volumes:
      - ./logs:/var/log/quantumai:rw
      - ./apps:/QuantumAI-Transfer-System:rw
    ports:
      - "8765:8765"
      - "8000:8000"
    healthcheck:
      test: ["CMD-SHELL","python3 - <<'PY'\nimport http.client as c\ntry:\n h=c.HTTPConnection('localhost',8000,timeout=2); h.request('GET','/health'); r=h.getresponse(); exit(0 if r.status==200 else 1)\nexcept Exception as e:\n exit(1)\nPY"]
      interval: 20s
      timeout: 5s
      retries: 5
      start_period: 30s
secrets:
  qai_env:
    file: .env
YML
  echo "[+] created: $QAI_DOCKER/docker-compose.yml"
fi

if [ ! -f "$QAI_DOCKER/scripts/start_all.sh" ]; then
  cat > "$QAI_DOCKER/scripts/start_all.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "[QAI] Ensuring Colima (Docker) is up…"
colima start || true
echo "[QAI] Building image if missing…"
docker image inspect quantumai-usdt.apps:latest >/dev/null 2>&1 || docker build -t quantumai-usdt.apps .
echo "[QAI] Starting compose…"
docker compose up -d
echo "[QAI] Tailing logs (Ctrl+C to detach)…"
docker compose logs -f --tail=200
SH
  chmod +x "$QAI_DOCKER/scripts/start_all.sh"
  echo "[+] created: $QAI_DOCKER/scripts/start_all.sh"
fi

if [ ! -e "$QAI_DOCKER/start_all.sh" ]; then
  ln -s "$QAI_DOCKER/scripts/start_all.sh" "$QAI_DOCKER/start_all.sh" || true
  echo "[+] linked: $QAI_DOCKER/start_all.sh -> scripts/start_all.sh"
fi

if [ ! -f "$QAI_DOCKER/ops/full_boot_manager.py" ]; then
  cat > "$QAI_DOCKER/ops/full_boot_manager.py" <<'PY'
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Append-safe ops helper: deps-sync | build | up | logs
"""
import os, sys, subprocess, shutil, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
def run(cmd): print("+", " ".join(cmd)); subprocess.check_call(cmd)

def deps_sync():
    print("[deps] nothing to do (dockerized).")

def build():
    os.chdir(str(ROOT))
    if shutil.which("colima"):
        try: run(["colima","start"])
        except subprocess.CalledProcessError: pass
    run(["docker","build","-t","quantumai-usdt.apps","."])

def up():
    os.chdir(str(ROOT))
    run(["docker","compose","up","-d"])

def logs():
    os.chdir(str(ROOT))
    run(["docker","compose","logs","-f","--tail=200"])

if __name__=="__main__":
    argv = sys.argv[1:]
    if not argv: sys.exit("usage: full_boot_manager.py [deps-sync|build|up|logs]")
    for arg in argv:
        {"deps-sync":deps_sync, "build":build, "up":up, "logs":logs}[arg]()
PY
  chmod +x "$QAI_DOCKER/ops/full_boot_manager.py"
  echo "[+] created: $QAI_DOCKER/ops/full_boot_manager.py"
fi

if [ -d "$ICLOUD_ROOT" ] && [ ! -e "$ICLOUD_ROOT/QuantumAI-Dockerized-System" ]; then
  ln -s "$QAI_DOCKER" "$ICLOUD_ROOT/QuantumAI-Dockerized-System" || true
  echo "[+] linked into iCloud Drive"
fi

cat > "$LAUNCHAGENTS/com.quantumai.colima.autostart.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.quantumai.colima.autostart</string>
  <key>ProgramArguments</key>
  <array><string>/opt/homebrew/bin/colima</string><string>start</string></array>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/tmp/colima.autostart.out</string>
  <key>StandardErrorPath</key><string>/tmp/colima.autostart.err</string>
</dict></plist>
PLIST

cat > "$LAUNCHAGENTS/com.quantumai.panel.autostart.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.quantumai.panel.autostart</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>-lc</string>
    <string>cd "$HOME/QuantumAI-Dockerized-System/scripts" && ./start_all.sh</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/qai.panel.out</string>
  <key>StandardErrorPath</key><string>/tmp/qai.panel.err</string>
</dict></plist>
PLIST

launchctl unload "$LAUNCHAGENTS/com.quantumai.colima.autostart.plist" 2>/dev/null || true
launchctl unload "$LAUNCHAGENTS/com.quantumai.panel.autostart.plist" 2>/dev/null || true
launchctl load  "$LAUNCHAGENTS/com.quantumai.colima.autostart.plist"
launchctl load  "$LAUNCHAGENTS/com.quantumai.panel.autostart.plist"

for f in "setup_quantum_ai_panel.sh" "setup_quantum_ai_panel_ripe.sh"; do
  target="$PCI_SCRIPTS/$f"; touch "$target"
  cat >> "$target" <<'APPEND'

if [ -x "/Users/erenuludemir/pci_admin_paneli/scripts/QuantumAI_Full_PKG_Installer.sh" ]; then
  sudo "/Users/erenuludemir/pci_admin_paneli/scripts/QuantumAI_Full_PKG_Installer.sh"
else
  echo "[WARN] QuantumAI_Full_PKG_Installer.sh bulunamadı (atlandı)."
fi

if [ -x "/Users/erenuludemir/pci_admin_paneli/scripts/generate_quantumai_dmg.sh" ]; then
  "/Users/erenuludemir/pci_admin_paneli/scripts/generate_quantumai_dmg.sh"
else
  echo "[WARN] generate_quantumai_dmg.sh bulunamadı (atlandı)."
fi

APPEND
  chmod +x "$target"
done

echo
echo "✅ Hazır. Çalıştırma seçenekleri:"
echo "   1) $QAI_DOCKER/scripts/start_all.sh"
echo "   2) cd $QAI_DOCKER && python3 ops/full_boot_manager.py deps-sync build up logs"
echo "   3) Otomatik: launchctl start com.quantumai.panel.autostart"
