from __future__ import annotations

import os
from pathlib import Path

LOG_DIR = Path(os.getenv("QAI_LOG_DIR", "/var/log/qai"))
LOG_DIR.mkdir(parents=True, exist_ok=True)

ACCESS_LOG = LOG_DIR / "access.log"
ERROR_LOG = LOG_DIR / "error.log"

for log_path in (ACCESS_LOG, ERROR_LOG):
    log_path.touch(exist_ok=True)

loglevel = os.getenv("QAI_LOG_LEVEL", "info").lower()
capture_output = True
accesslog = "-"
errorlog = "-"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"'

logconfig_dict = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "default": {
            "format": "[%(asctime)s] %(levelname)s %(name)s: %(message)s",
        },
        "access": {
            "format": "%(message)s",
        },
    },
    "handlers": {
        "error_console": {
            "class": "logging.StreamHandler",
            "formatter": "default",
            "stream": "ext://sys.stderr",
        },
        "access_console": {
            "class": "logging.StreamHandler",
            "formatter": "access",
            "stream": "ext://sys.stdout",
        },
        "error_file": {
            "class": "logging.handlers.WatchedFileHandler",
            "formatter": "default",
            "filename": str(ERROR_LOG),
        },
        "access_file": {
            "class": "logging.handlers.WatchedFileHandler",
            "formatter": "access",
            "filename": str(ACCESS_LOG),
        },
    },
    "loggers": {
        "gunicorn.error": {
            "handlers": ["error_console", "error_file"],
            "level": loglevel.upper(),
            "propagate": False,
        },
        "gunicorn.access": {
            "handlers": ["access_console", "access_file"],
            "level": "INFO",
            "propagate": False,
        },
    },
    "root": {
        "handlers": ["error_console", "error_file"],
        "level": loglevel.upper(),
    },
}
