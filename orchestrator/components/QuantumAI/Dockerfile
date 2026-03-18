FROM python:3.11-slim
WORKDIR /srv/quantumai
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir -r requirements.txt || true
COPY . .
ENV GUNICORN_WORKERS=2 GUNICORN_MAX_REQUESTS=1000 GUNICORN_MAX_REQUESTS_JITTER=50
CMD ["python","-c","print('QuantumAI placeholder service - implement model server')"]
