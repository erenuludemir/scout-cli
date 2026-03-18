#!/usr/bin/env python3
import subprocess, os, time
def ready():
  try: subprocess.check_output(["docker", "info"], stderr=subprocess.DEVNULL); return True
  except: return False
while True:
  if not ready(): os.system("open -a Docker")
  time.sleep(30)
