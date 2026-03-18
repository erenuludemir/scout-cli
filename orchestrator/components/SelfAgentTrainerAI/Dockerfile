FROM python:3.11-slim
WORKDIR /srv/selfagenttrainerai
COPY requirements.txt /tmp/req.txt
RUN pip install --no-cache-dir -r /tmp/req.txt || true
COPY . .
ENV SERVICE_NAME=SelfAgentTrainerAI
CMD ["python","app/main.py"]
