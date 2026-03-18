## Multi-stage lightweight image for quantumai-usdt-v2 service
FROM python:3.12-slim AS base
# NOTE: For tighter supply-chain control you can pin to a specific digest:
#   Use scripts/update_base_digest.sh then replace the FROM line with
#   FROM python:3.11-slim@sha256:<digest>
# Rebuild & rescan (Trivy) after updating.

ENV PYTHONDONTWRITEBYTECODE=1 \
	PYTHONUNBUFFERED=1 \
	PIP_NO_CACHE_DIR=1

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
# Copy requirement spec (constraints optional)
COPY requirements.txt ./requirements.txt
# Copy constraints.txt only if it exists in build context (ignored if absent)
ADD constraints.txt ./constraints.txt
# Install dependencies (fallback if constraints missing or empty)
RUN pip install --upgrade pip && \
	if [ -s constraints.txt ]; then \
		pip install -c constraints.txt -r requirements.txt gunicorn; \
	else \
		pip install -r requirements.txt gunicorn; \
	fi

COPY . /app

# Create non-root user
RUN useradd -m svc \
 && mkdir -p /var/log/qai \
 && chown -R svc:svc /app /var/log/qai \
 && chmod 0775 /var/log/qai
USER svc

EXPOSE 5002
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 CMD curl -fsS http://127.0.0.1:5002/health || exit 1

# runtime: gunicorn app:app
ENTRYPOINT ["gunicorn", "-c", "/app/gunicorn.conf.py", "app:app", "--bind", "0.0.0.0:5002", "--workers", "2", "--threads", "4", "--timeout", "60"]
