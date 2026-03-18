import logging
import os
import time

APP_ROOT = os.environ.get("APP_ROOT") or os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
log_dir = os.environ.get("QAI_LOG_DIR", os.path.join(APP_ROOT, ".qai", "logs"))
os.makedirs(log_dir, exist_ok=True)
log_path = os.path.join(log_dir, "brlct_monitor.log")

# Configure logger (single handler, avoid duplicate basicConfig calls)
logger = logging.getLogger("brlct_monitor")
if not logger.handlers:
    logger.setLevel(logging.INFO)
    fh = logging.FileHandler(log_path)
    fmt = logging.Formatter("%(asctime)s - %(message)s")
    fh.setFormatter(fmt)
    logger.addHandler(fh)
logger.propagate = False
logger.info("brlct_monitor başlatıldı (APP_ROOT=%s, log_dir=%s)", APP_ROOT, log_dir)

def monitor_loop():
    """
    Continuously logs the status of the monitoring process every 60 seconds.
    
    Parameters:
    None
    
    Returns:
    None
    
    Exceptions:
    None
    """
    while True:
        logger.info("Monitoring still active...")
        time.sleep(60)

if __name__ == "__main__":
    monitor_loop()
