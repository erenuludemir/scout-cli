FROM python:3.10-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt /tmp/requirements.txt
COPY requirements.lock /tmp/requirements.lock

RUN python -m pip install -U pip \
 && python -m pip install --no-cache-dir -r /tmp/requirements.lock

COPY . /app
CMD ["python","app.py"]
