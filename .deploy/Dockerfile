FROM python:3.11-slim
RUN apt-get update && apt-get install -y --no-install-recommends nginx supervisor curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN python -m pip install -U pip && pip install --no-cache-dir -r /app/requirements.txt
COPY . /app
COPY .deploy/wsgi.py /app/wsgi.py
RUN mkdir -p /run/nginx /var/log/supervisor
COPY .deploy/nginx.conf /etc/nginx/nginx.conf
COPY .deploy/supervisord.conf /etc/supervisor/supervisord.conf
EXPOSE 8080
CMD ["/usr/bin/supervisord","-c","/etc/supervisor/supervisord.conf"]
