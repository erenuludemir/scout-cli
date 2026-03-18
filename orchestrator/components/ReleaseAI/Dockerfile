FROM python:3.12-slim
WORKDIR /srv/releaseai
COPY requirements.txt /tmp/req.txt
RUN pip install --no-cache-dir -r /tmp/req.txt || true
COPY . .
ENV SERVICE_NAME=ReleaseAI
CMD ["python","app/main.py"]
