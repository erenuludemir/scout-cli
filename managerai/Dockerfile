FROM docker:27-cli AS docker_cli

FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app \
    DOCKER_HOST=unix:///var/run/docker.sock \
    SUPERVIZOR_COMPOSE_FILES=compose.master.yml,compose.yml,compose.override.yml,docker-compose.base.yml,docker-compose.override.yml,compose.managerai.yml \
    SUPERVIZOR_HISTORY_FILE=/app/_logs/manager_ai/history.jsonl

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=docker_cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker_cli /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins

COPY managerai/requirements.txt /tmp/requirements.txt
RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir -r /tmp/requirements.txt

COPY orchestrator /app/orchestrator
COPY managerai /app/managerai
COPY compose.master.yml compose.yml compose.override.yml docker-compose.base.yml docker-compose.override.yml compose.managerai.yml /app/

RUN mkdir -p /app/_logs/manager_ai /app/_logs/managerai /app/_state/managerai /app/_reports/managerai

EXPOSE 8012 8787

HEALTHCHECK --interval=60s --timeout=30s --start-period=60s CMD ["sh", "-c", "curl -fsS http://127.0.0.1:8012/healthz >/dev/null || exit 1"]

CMD ["uvicorn", "managerai.app:app", "--host", "0.0.0.0", "--port", "8012"]
