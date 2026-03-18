FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx supervisor curl && \
    pip install --upgrade pip

WORKDIR /app

COPY . /app

COPY .deploy/nginx.conf /etc/nginx/nginx.conf
COPY .deploy/supervisord.conf /etc/supervisor/supervisord.conf

RUN mkdir -p /app/run /app/log/supervisor && \
    pip install --no-cache-dir -r requirements.txt

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s CMD curl -f http://localhost:8080/health || exit 1

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]