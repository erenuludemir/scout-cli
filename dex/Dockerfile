FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /var/log/qai && chmod 0775 /var/log/qai
COPY requirements.txt /tmp/requirements.txt
RUN python -m pip install --no-cache-dir -r /tmp/requirements.txt
COPY . /app
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=5s --retries=12 --start-period=3s \
  CMD curl -fsS http://127.0.0.1:8080/health || exit 1
CMD ["gunicorn","-c","/app/gunicorn.conf.py","-b","0.0.0.0:8080","-w","2","-k","gthread","--threads","4","--timeout","60","main:app"]
