#!/usr/bin/env python3
"""Generate component skeletons if missing.
Creates Dockerfile + app/main.py placeholder for each name in COMPONENTS.txt.
Idempotent: does not overwrite existing files.
"""
from __future__ import annotations
import pathlib
ROOT = pathlib.Path(__file__).resolve().parent
COMP_FILE = ROOT / 'components' / 'COMPONENTS.txt'
BASE_DIR = ROOT / 'components'

DOCKERFILE_TMPL = """FROM python:3.11-slim
WORKDIR /srv/{name_l}
COPY requirements.txt /tmp/req.txt
RUN pip install --no-cache-dir -r /tmp/req.txt || true
COPY . .
ENV SERVICE_NAME={name}
CMD ["python","app/main.py"]
"""

APP_MAIN_TMPL = """#!/usr/bin/env python3
import json, os, time, socket
from http.server import BaseHTTPRequestHandler, HTTPServer
SERVICE = os.environ.get('SERVICE_NAME','{name}')
START = time.time()

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/health'):
            body = json.dumps({{'service':SERVICE,'uptime_s': round(time.time()-START,2),'status':'ok'}})
            self.send_response(200)
            self.send_header('Content-Type','application/json')
            self.end_headers()
            self.wfile.write(body.encode())
        else:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(f"{name} service placeholder".encode())

if __name__ == '__main__':
    port=int(os.environ.get('PORT','8080'))
    HTTPServer(('0.0.0.0',port),H).serve_forever()
"""

def main():
    names = [line.strip() for line in COMP_FILE.read_text().splitlines() if line.strip()]
    created = []
    for name in names:
        comp_dir = BASE_DIR / name
        app_dir = comp_dir / 'app'
        if not comp_dir.exists():
            app_dir.mkdir(parents=True, exist_ok=True)
            (comp_dir / 'Dockerfile').write_text(DOCKERFILE_TMPL.format(name=name, name_l=name.lower()))
            (app_dir / 'main.py').write_text(APP_MAIN_TMPL.format(name=name))
            created.append(name)
    print({'created': created})

if __name__ == '__main__':
    main()
