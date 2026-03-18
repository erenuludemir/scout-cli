FROM python:3.11-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY main.py .
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=4s --start-period=10s --retries=3 CMD curl -fsS http://127.0.0.1:8000/health >/dev/null || exit 1
CMD ["uvicorn","main:app","--host","0.0.0.0","--port","8000"]
