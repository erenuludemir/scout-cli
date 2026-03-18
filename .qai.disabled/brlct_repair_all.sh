#!/bin/bash
set -euo pipefail

APP_ROOT="${APP_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
QAI_DIR="${APP_ROOT}/.qai"
LOG_DIR="${QAI_DIR}/logs"
echo "[QAI] Log klasörü oluşturuluyor... ($LOG_DIR)"
mkdir -p "${LOG_DIR}"

echo "[QAI] brlct_monitor.py güncelleniyor... ($QAI_DIR)"
cat > "${QAI_DIR}/brlct_monitor.py" <<EOF
import logging, os, time

log_dir = os.environ.get("QAI_LOG_DIR", "${LOG_DIR}")
os.makedirs(log_dir, exist_ok=True)
log_path = os.path.join(log_dir, "brlct_monitor.log")

logging.basicConfig(filename=log_path, level=logging.INFO, format="%(asctime)s - %(message)s")

def monitor_loop():
    while True:
        logging.info("Monitoring still active...")
        time.sleep(60)

if __name__ == "__main__":
    monitor_loop()
EOF

echo "[QAI] Log başlatılıyor... (python3 ${QAI_DIR}/brlct_monitor.py)"
QAI_LOG_DIR="${LOG_DIR}" nohup python3 "${QAI_DIR}/brlct_monitor.py" > /dev/null 2>&1 &

echo "[QAI] Terminal tail başlatılıyor... (log: ${LOG_DIR}/brlct_monitor.log)"
open -a Terminal "$(which tail)" -f "${LOG_DIR}/brlct_monitor.log" || true
