FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY . /app

RUN python -m pip install --upgrade pip && \
    python -m pip install --no-cache-dir -r requirements.txt && \
    mkdir -p /var/log/qai && \
    chmod 0775 /var/log/qai

EXPOSE 5002

HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 CMD python -c "import sys, urllib.request; r = urllib.request.urlopen('http://127.0.0.1:5002/', timeout=3); sys.exit(0 if r.status == 200 else 1)"

# runtime: gunicorn app:app
ENTRYPOINT ["gunicorn", "-c", "/app/gunicorn.conf.py", "app:app", "--bind", "0.0.0.0:5002", "--workers", "2", "--threads", "4", "--timeout", "60"]
