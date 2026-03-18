#!/usr/bin/env python3
import shutil
f = shutil.which("forc")
print("❌ Fuel (forc) bulunamadı." if not f else f"✅ Fuel hazır: {f}")
