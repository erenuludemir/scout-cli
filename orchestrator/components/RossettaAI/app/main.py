#!/usr/bin/env python3
import json
import os
import time
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
SERVICE = os.environ.get('SERVICE_NAME','RossettaAI')
START = time.time()
MODEL_PATH = os.environ.get('MODEL_PATH','/modeldata/trainedmodel.json')
_model_lock = threading.Lock()
_model = None

def load_model():
    global _model
    try:
        with open(MODEL_PATH,'r') as f:
            _model = json.load(f)
    except Exception as e:
        _model = {'error': str(e), 'loaded': False}

load_model()

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/health'):
            body = json.dumps({'service':SERVICE,'uptime_s': round(time.time()-START,2),'status':'ok'})
            self.send_response(200)
            self.send_header('Content-Type','application/json')
            self.end_headers()
            self.wfile.write(body.encode())
        elif self.path.startswith('/model'):
            with _model_lock:
                body = json.dumps({'service': SERVICE, 'model': _model})
            self.send_response(200)
            self.send_header('Content-Type','application/json')
            self.end_headers()
            self.wfile.write(body.encode())
        elif self.path.startswith('/predict'):
            # Placeholder prediction echoing query params
            from urllib.parse import urlparse, parse_qs
            qs = parse_qs(urlparse(self.path).query)
            inp = qs.get('q',[''])[0]
            with _model_lock:
                model_id = _model.get('id') if isinstance(_model, dict) else None
            resp = {'service': SERVICE, 'input': inp, 'model_id': model_id, 'prediction': inp[::-1]}
            body = json.dumps(resp)
            self.send_response(200)
            self.send_header('Content-Type','application/json')
            self.end_headers()
            self.wfile.write(body.encode())
        else:
            self.send_response(200)
            self.end_headers()
            self.wfile.write("RossettaAI service placeholder".encode())

if __name__ == '__main__':
    port=int(os.environ.get('PORT','8080'))
    HTTPServer(('0.0.0.0',port),H).serve_forever()
