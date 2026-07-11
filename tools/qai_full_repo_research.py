#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import csv
import html
import json
import os
import re
import sys
import time
from collections import Counter
from datetime import datetime
from pathlib import Path

SKIP_DIRS = {
    ".git",".hg",".svn","__pycache__",".pytest_cache",".mypy_cache",".ruff_cache",
    ".idea",".vscode",".venv","venv","env","node_modules","dist","build",".next",
    ".nuxt",".turbo","coverage",".coverage",".gradle",".terraform",".serverless",
    ".aws-sam",".cache",".tox",".eggs","_repo_research"
}

BINARY_EXTS = {
    ".png",".jpg",".jpeg",".gif",".webp",".bmp",".ico",".icns",".pdf",".zip",".gz",
    ".tgz",".bz2",".xz",".7z",".rar",".tar",".dmg",".pkg",".mp3",".wav",".m4a",".aac",
    ".mp4",".mov",".avi",".mkv",".bin",".exe",".dll",".so",".dylib",".o",".a",".class",
    ".jar",".war",".ear",".pyc",".pyo",".pyd",".whl",".ttf",".otf",".woff",".woff2",
    ".sqlite",".sqlite3",".db",".db-shm",".db-wal",".mdb",".psd",".ai",".sketch",".fig",
    ".heic",".apk",".ipa",".xcarchive",".metallib",".air"
}

COMMENT_PREFIXES = ("#", "//", ";", "--", "%")

def is_binary(path: Path) -> bool:
    if path.suffix.lower() in BINARY_EXTS:
        return True
    try:
        with path.open("rb") as f:
            chunk = f.read(4096)
        return b"\x00" in chunk
    except Exception:
        return True

def read_text(path: Path, max_bytes: int = 131072):
    try:
        size = path.stat().st_size
        truncated = size > max_bytes
        with path.open("rb") as f:
            raw = f.read(max_bytes)
        for enc in ("utf-8", "utf-8-sig", "latin-1"):
            try:
                return raw.decode(enc, errors="replace"), truncated, enc
            except Exception:
                pass
        return raw.decode("utf-8", errors="replace"), truncated, "utf-8"
    except Exception as e:
        return f"<<READ_ERROR:{e}>>", False, ""

def first_nonempty_line(text: str) -> str:
    for line in text.splitlines():
        s = line.strip()
        if s:
            return s[:300]
    return ""

def first_comment(text: str) -> str:
    for line in text.splitlines()[:80]:
        s = line.strip()
        if s.startswith(COMMENT_PREFIXES):
            return re.sub(r"^(#|//|;|--|%)+\s*", "", s).strip()[:300]
    return ""

def md_heading(text: str) -> str:
    for line in text.splitlines()[:100]:
        s = line.strip()
        if s.startswith("#"):
            return s.lstrip("#").strip()[:300]
    return ""

def html_title(text: str) -> str:
    m = re.search(r"<title[^>]*>(.*?)</title>", text, re.I | re.S)
    if m:
        return re.sub(r"\s+", " ", m.group(1)).strip()[:300]
    return ""

def json_keys(text: str):
    try:
        obj = json.loads(text)
        if isinstance(obj, dict):
            return list(obj.keys())[:20]
    except Exception:
        pass
    return []

def env_keys(text: str):
    out = []
    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith("#") or "=" not in s:
            continue
        k = s.split("=", 1)[0].strip()
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", k):
            out.append(k)
    return sorted(set(out))[:100]

def make_targets(text: str):
    out = []
    for line in text.splitlines():
        if re.match(r"^[A-Za-z0-9_.-]+:\s*(?:##.*)?$", line) and not line.startswith("\t"):
            tgt = line.split(":", 1)[0].strip()
            if tgt not in {"if", "for", "while", "else"}:
                out.append(tgt)
    return sorted(set(out))[:100]

def compose_services(text: str):
    services = []
    in_services = False
    for line in text.splitlines():
        if re.match(r"^\s*services\s*:\s*$", line):
            in_services = True
            continue
        if in_services:
            if re.match(r"^\S", line):
                break
            m = re.match(r"^\s{2,}([A-Za-z0-9._-]+)\s*:\s*$", line)
            if m:
                services.append(m.group(1))
    return sorted(set(services))[:100]

def python_imports(text: str):
    hits = re.findall(r"^\s*(?:from\s+([A-Za-z0-9_\.]+)\s+import|import\s+([A-Za-z0-9_\.]+))", text, re.M)
    out = []
    for a, b in hits:
        if a:
            out.append(a)
        if b:
            out.append(b)
    return sorted(set(out))[:80]

def python_functions(text: str):
    return sorted(set(re.findall(r"^\s*def\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", text, re.M)))[:120]

def python_classes(text: str):
    return sorted(set(re.findall(r"^\s*class\s+([A-Za-z_][A-Za-z0-9_]*)\s*[\(:]", text, re.M)))[:80]

def python_routes(text: str):
    out = []
    for method, path in re.findall(r"""@(?:app|router)\.(get|post|put|delete|patch)\(\s*['"]([^'"]+)""", text):
        out.append(f"{method.upper()} {path}")
    for path in re.findall(r"""@(?:app|bp|blueprint)\.route\(\s*['"]([^'"]+)""", text):
        out.append(f"ROUTE {path}")
    return sorted(set(out))[:80]

def role_of(path: Path) -> str:
    name = path.name.lower()
    suffix = path.suffix.lower()
    rel = str(path).lower()
    if name in {"docker-compose.yml","docker-compose.yaml","compose.yml","compose.yaml"} or ("compose" in name and suffix in {".yml",".yaml"}):
        return "docker_compose"
    if name == "dockerfile" or name.startswith("dockerfile"):
        return "dockerfile"
    if name.startswith(".env") or suffix == ".env":
        return "env_config"
    if name == "makefile":
        return "makefile"
    if suffix == ".py":
        return "python"
    if suffix in {".sh",".bash",".zsh"}:
        return "shell"
    if suffix in {".js",".mjs",".cjs",".ts",".tsx",".jsx"}:
        return "javascript_typescript"
    if suffix == ".swift":
        return "swift"
    if suffix in {".html",".htm"}:
        return "html"
    if suffix in {".md",".rst",".txt"}:
        return "documentation"
    if suffix == ".json":
        return "json"
    if suffix in {".yaml",".yml"}:
        return "yaml"
    if suffix == ".plist":
        return "plist"
    if suffix == ".sql":
        return "sql"
    if suffix in {".conf",".cfg",".ini",".toml"}:
        return "config"
    if "/ios/" in rel or ".xcodeproj" in rel or ".xcworkspace" in rel:
        return "apple_project"
    if is_binary(path):
        return "binary"
    return "other"

def usage_hint(path: Path, role: str) -> str:
    p = str(path)
    if role == "docker_compose":
        return f'docker compose -f "{p}" config && docker compose -f "{p}" up -d'
    if role == "dockerfile":
        return f'docker build -f "{p}" -t local/{path.name.lower().replace(".", "-")}:dev .'
    if role == "env_config":
        return f'cp "{p}" "{p}.runtime"'
    if role == "makefile":
        return f'make -f "{p}" help || make -f "{p}"'
    if role == "python":
        return f'python3 "{p}" --help || python3 "{p}"'
    if role == "shell":
        return f'bash "{p}"'
    if role == "javascript_typescript":
        return f'node "{p}"'
    if role == "plist":
        return f'plutil -lint "{p}"'
    if role in {"html","documentation","other","json","yaml","config"}:
        return f'open "{p}"'
    if role == "sql":
        return f'sqlite3 local.db < "{p}"'
    return f'open "{p}"'

def summarize(path: Path, text: str, role: str) -> str:
    s = first_comment(text) or md_heading(text) or html_title(text) or first_nonempty_line(text)
    if role == "env_config":
        keys = env_keys(text)
        if keys:
            return "Ortam değişkenleri: " + ", ".join(keys[:20])
    if role == "makefile":
        tgts = make_targets(text)
        if tgts:
            return "Make hedefleri: " + ", ".join(tgts[:20])
    if role == "docker_compose":
        svcs = compose_services(text)
        if svcs:
            return "Compose servisleri: " + ", ".join(svcs[:20])
    if role == "json":
        keys = json_keys(text)
        if keys:
            return "JSON anahtarları: " + ", ".join(keys[:20])
    if role == "python":
        funcs = python_functions(text)
        classes = python_classes(text)
        routes = python_routes(text)
        parts = []
        if s:
            parts.append(s)
        if routes:
            parts.append("endpoint=" + ", ".join(routes[:10]))
        if classes:
            parts.append("sınıf=" + ", ".join(classes[:10]))
        if funcs:
            parts.append("fonksiyon=" + ", ".join(funcs[:12]))
        return " | ".join(parts)[:1000] if parts else "Python modülü/scripti"
    return s[:1000] if s else role

def find_files(root: Path):
    files = []
    dir_count = 0
    for cur, dirs, names in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        dir_count += len(dirs)
        base = Path(cur)
        for name in names:
            files.append(base / name)
    return files, dir_count

def scan_one(path: Path, root: Path, max_bytes: int):
    rel = str(path.relative_to(root))
    st = path.stat()
    role = role_of(path)
    binary = is_binary(path)
    row = {
        "relative_path": rel,
        "name": path.name,
        "suffix": path.suffix.lower(),
        "size": st.st_size,
        "mtime": datetime.fromtimestamp(st.st_mtime).isoformat(timespec="seconds"),
        "binary": binary,
        "role": role,
        "summary": "",
        "usage_hint": usage_hint(path, role),
        "imports": "",
        "classes": "",
        "functions": "",
        "routes": "",
        "env_vars": "",
        "services_or_targets": "",
        "encoding": "",
        "truncated": False,
    }
    if binary:
        row["summary"] = "Binary/medya/artifact dosyası"
        return row

    text, truncated, encoding = read_text(path, max_bytes=max_bytes)
    row["encoding"] = encoding
    row["truncated"] = truncated
    row["summary"] = summarize(path, text, role)

    if role == "python":
        row["imports"] = ", ".join(python_imports(text)[:40])
        row["classes"] = ", ".join(python_classes(text)[:40])
        row["functions"] = ", ".join(python_functions(text)[:60])
        row["routes"] = ", ".join(python_routes(text)[:40])
        envs = sorted(set(re.findall(r"""(?:os\.getenv|os\.environ\.get)\(\s*['"]([A-Z0-9_]+)['"]""", text)))[:60]
        row["env_vars"] = ", ".join(envs)
    elif role == "env_config":
        row["env_vars"] = ", ".join(env_keys(text)[:80])
    elif role == "makefile":
        row["services_or_targets"] = ", ".join(make_targets(text)[:80])
    elif role == "docker_compose":
        row["services_or_targets"] = ", ".join(compose_services(text)[:80])

    return row

def write_csv(path: Path, rows, fieldnames):
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for row in rows:
            w.writerow({k: row.get(k, "") for k in fieldnames})

def build_dir_summary(file_rows):
    stats = {}
    for row in file_rows:
        parent = str(Path(row["relative_path"]).parent)
        if parent not in stats:
            stats[parent] = {"directory": parent, "files": 0, "bytes": 0, "roles": Counter(), "exts": Counter()}
        stats[parent]["files"] += 1
        stats[parent]["bytes"] += int(row["size"])
        stats[parent]["roles"][row["role"]] += 1
        stats[parent]["exts"][row["suffix"] or "<none>"] += 1

    out = []
    for d, v in stats.items():
        out.append({
            "directory": d,
            "files": v["files"],
            "bytes": v["bytes"],
            "top_roles": ", ".join([f"{k}:{n}" for k, n in v["roles"].most_common(8)]),
            "top_extensions": ", ".join([f"{k}:{n}" for k, n in v["exts"].most_common(8)]),
        })
    out.sort(key=lambda x: (-x["files"], x["directory"]))
    return out

def render_md(root: Path, summary: dict, file_rows, dir_rows):
    role_counts = Counter([r["role"] for r in file_rows])
    ext_counts = Counter([(r["suffix"] or "<none>") for r in file_rows])
    biggest = sorted(file_rows, key=lambda x: int(x["size"]), reverse=True)[:50]

    lines = []
    lines.append("# QuantumAI Repo Araştırma Raporu")
    lines.append("")
    lines.append(f"- Kök dizin: `{root}`")
    lines.append(f"- Tarama zamanı: `{summary['scanned_at']}`")
    lines.append(f"- Toplam dizin: `{summary['directory_count']}`")
    lines.append(f"- Toplam dosya: `{summary['file_count']}`")
    lines.append(f"- Metin dosyası: `{summary['text_file_count']}`")
    lines.append(f"- Binary dosya: `{summary['binary_file_count']}`")
    lines.append(f"- Toplam boyut: `{summary['total_bytes']}` byte")
    lines.append("")
    lines.append("## Rol Dağılımı")
    lines.append("")
    for k, v in role_counts.most_common():
        lines.append(f"- `{k}`: {v}")
    lines.append("")
    lines.append("## Uzantı Dağılımı")
    lines.append("")
    for k, v in ext_counts.most_common(80):
        lines.append(f"- `{k}`: {v}")
    lines.append("")
    lines.append("## En Büyük Dosyalar")
    lines.append("")
    for r in biggest:
        lines.append(f"- `{r['relative_path']}` | {r['size']} byte | {r['role']} | {r['summary']}")
    lines.append("")
    lines.append("## Kritik Klasörler")
    lines.append("")
    for d in dir_rows[:200]:
        lines.append(f"- `{d['directory']}` | dosya={d['files']} | byte={d['bytes']} | roller={d['top_roles']} | uzantılar={d['top_extensions']}")
    lines.append("")
    lines.append("## Çıktılar")
    lines.append("")
    lines.append("- `repo_inventory.csv`")
    lines.append("- `directory_inventory.csv`")
    lines.append("- `repo_summary.json`")
    lines.append("- `repo_research_report.md`")
    lines.append("- `repo_research_report.html`")
    return "\n".join(lines)

def render_html(md_text: str):
    return f"""<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>QuantumAI Repo Araştırma Raporu</title>
<style>
body{{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica,Arial,sans-serif;background:#0b1020;color:#e6edf3;max-width:1400px;margin:0 auto;padding:24px;line-height:1.5}}
pre{{white-space:pre-wrap;word-break:break-word;background:#111827;padding:16px;border-radius:12px}}
</style>
</head>
<body>
<pre>{html.escape(md_text)}</pre>
</body>
</html>"""

def main():
    ap = argparse.ArgumentParser(description="Repo içeriğini tarar, dosya bazlı araştırma raporu üretir.")
    ap.add_argument("--root", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--max-bytes", type=int, default=131072)
    args = ap.parse_args()

    root = Path(args.root).expanduser().resolve()
    out = Path(args.out).expanduser().resolve()
    out.mkdir(parents=True, exist_ok=True)

    if not root.exists() or not root.is_dir():
        print(f"KOK_DIZIN_YOK:{root}", file=sys.stderr)
        sys.exit(2)

    start = time.time()
    files, dir_count = find_files(root)
    rows = []
    total = len(files)

    for i, path in enumerate(files, 1):
        try:
            rows.append(scan_one(path, root, args.max_bytes))
        except Exception as e:
            rows.append({
                "relative_path": str(path.relative_to(root)),
                "name": path.name,
                "suffix": path.suffix.lower(),
                "size": path.stat().st_size if path.exists() else 0,
                "mtime": "",
                "binary": "",
                "role": "scan_error",
                "summary": f"SCAN_ERROR:{e}",
                "usage_hint": f'open "{path}"',
                "imports": "",
                "classes": "",
                "functions": "",
                "routes": "",
                "env_vars": "",
                "services_or_targets": "",
                "encoding": "",
                "truncated": False,
            })
        if i % 500 == 0 or i == total:
            print(f"[{i}/{total}] tarandı", file=sys.stderr)

    rows.sort(key=lambda x: x["relative_path"])
    dir_rows = build_dir_summary(rows)

    text_count = sum(1 for r in rows if r["binary"] is False)
    binary_count = sum(1 for r in rows if r["binary"] is True)
    total_bytes = sum(int(r["size"]) for r in rows)

    summary = {
        "root": str(root),
        "scanned_at": datetime.now().isoformat(timespec="seconds"),
        "elapsed_seconds": round(time.time() - start, 3),
        "directory_count": dir_count,
        "file_count": len(rows),
        "text_file_count": text_count,
        "binary_file_count": binary_count,
        "total_bytes": total_bytes,
        "role_counts": dict(Counter([r["role"] for r in rows])),
        "extension_counts": dict(Counter([(r["suffix"] or "<none>") for r in rows])),
    }

    inventory_csv = out / "repo_inventory.csv"
    dir_csv = out / "directory_inventory.csv"
    summary_json = out / "repo_summary.json"
    report_md = out / "repo_research_report.md"
    report_html = out / "repo_research_report.html"

    write_csv(
        inventory_csv,
        rows,
        [
            "relative_path", "name", "suffix", "size", "mtime", "binary", "role",
            "summary", "usage_hint", "imports", "classes", "functions", "routes",
            "env_vars", "services_or_targets", "encoding", "truncated"
        ]
    )
    write_csv(
        dir_csv,
        dir_rows,
        ["directory", "files", "bytes", "top_roles", "top_extensions"]
    )

    with summary_json.open("w", encoding="utf-8") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)

    md = render_md(root, summary, rows, dir_rows)
    report_md.write_text(md, encoding="utf-8")
    report_html.write_text(render_html(md), encoding="utf-8")

    print(f"RAPOR_HAZIR:{report_md}")
    print(f"HTML_RAPOR:{report_html}")
    print(f"DOSYA_ENVANTERI:{inventory_csv}")
    print(f"DIZIN_ENVANTERI:{dir_csv}")
    print(f"OZET_JSON:{summary_json}")
    print(f"TOPLAM_DIZIN:{dir_count}")
    print(f"TOPLAM_DOSYA:{len(rows)}")
    print(f"SURE_SN:{round(time.time() - start, 3)}")

if __name__ == "__main__":
    main()
