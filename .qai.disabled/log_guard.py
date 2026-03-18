#!/usr/bin/env python3
import os, time
from pathlib import Path
D = ["/var/log", "/private/var/log", str(Path.home() / "Library/Logs"), str(Path.home() / "QuantumAI-Dockerized-System/.qai")]
def clear(p):
  for r, _, fs in os.walk(p):
    for f in fs:
      if f.endswith(".log"):
        fp = os.path.join(r, f)
        try:
          if os.path.getsize(fp) > 100 * 1024 * 1024:
            with open(fp, "w") as lf: lf.truncate(0)
        except: pass
while True:
  for d in D: clear(d)
  time.sleep(30)
