#!/usr/bin/env python3
"""Minimal local training harness placeholder.
Goals:
- Discover /data/training/*.jsonl
- Count samples and print a JSON summary (future: fine-tune step)
"""
from __future__ import annotations
import json
import pathlib
from datetime import datetime

DATA_DIR = pathlib.Path('/data/training')

def main():
    files = sorted(DATA_DIR.glob('*.jsonl')) if DATA_DIR.exists() else []
    total = 0
    for f in files:
        with f.open() as fh:
            for _ in fh:
                total += 1
    summary = {
        'timestamp': datetime.utcnow().isoformat()+'Z',
        'files': [str(f) for f in files],
        'sample_count': total,
        'status': 'ok'
    }
    print(json.dumps(summary, indent=2))
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
