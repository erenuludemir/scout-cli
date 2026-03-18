FROM python:3.11-slim
WORKDIR /srv/decisionai
COPY requirements.txt /tmp/req.txt
RUN pip install --no-cache-dir -r /tmp/req.txt || true
COPY . .
ENV SERVICE_NAME=DecisionAI
CMD ["python","app/main.py"]
