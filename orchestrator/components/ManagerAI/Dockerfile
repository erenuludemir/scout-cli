FROM python:3.11-slim
WORKDIR /srv/managerai
COPY requirements.txt /tmp/req.txt
RUN pip install --no-cache-dir -r /tmp/req.txt || true
COPY . .
ENV SERVICE_NAME=ManagerAI
CMD ["python","app/main.py"]
