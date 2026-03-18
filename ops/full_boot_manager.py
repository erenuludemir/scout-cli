#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Append-safe ops helper: deps-sync | build | up | logs
"""
import os, sys, subprocess, shutil, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
def run(cmd): print("+", " ".join(cmd)); subprocess.check_call(cmd)

def deps_sync():
    print("[deps] nothing to do (dockerized).")

def build():
    os.chdir(str(ROOT))
    if shutil.which("colima"):
        try: run(["colima","start"])
        except subprocess.CalledProcessError: pass
    run(["docker","build","-t","quantumai-usdt.apps","."])

def up():
    os.chdir(str(ROOT))
    run(["docker","compose","up","-d"])

def logs():
    os.chdir(str(ROOT))
    run(["docker","compose","logs","-f","--tail=200"])

if __name__=="__main__":
    argv = sys.argv[1:]
    if not argv: sys.exit("usage: full_boot_manager.py [deps-sync|build|up|logs]")
    for arg in argv:
        {"deps-sync":deps_sync, "build":build, "up":up, "logs":logs}[arg]()
