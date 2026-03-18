#!/usr/bin/env python3
import json, os, time, socket
from http.server import BaseHTTPRequestHandler, HTTPServer
SERVICE = os.environ.get('SERVICE_NAME','ManagerAI')
START = time.time()

class H(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith('/health'):
            body = json.dumps({'service':SERVICE,'uptime_s': round(time.time()-START,2),'status':'ok'})
            self.send_response(200)
            self.send_header('Content-Type','application/json')
            self.end_headers()
            self.wfile.write(body.encode())
        else:
            self.send_response(200)
            self.end_headers()
            self.wfile.write(f"ManagerAI service placeholder".encode())

if __name__ == '__main__':
    port=int(os.environ.get('PORT','8080'))
    HTTPServer(('0.0.0.0',port),H).serve_forever()
