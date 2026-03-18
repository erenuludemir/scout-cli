FROM python:3.11-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/* && pip install --upgrade pip
WORKDIR /app
RUN mkdir -p /var/log/qai && chmod 0775 /var/log/qai
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt
COPY . /app
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=5 CMD curl -fsS http://127.0.0.1:8000/health || exit 1
CMD ["gunicorn","-c","/app/gunicorn.conf.py","-b","0.0.0.0:8000","app:app"]
