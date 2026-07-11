#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import csv
import html
import json
import os
import re
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path

TEXTLIKE_SUFFIXES = {
    ".py", ".sh", ".bash", ".zsh", ".js", ".mjs", ".cjs", ".ts", ".tsx", ".jsx",
    ".json", ".yaml", ".yml", ".toml", ".ini", ".cfg", ".conf", ".env",
    ".md", ".txt", ".rst", ".html", ".htm", ".css", ".xml", ".plist",
    ".log", ".csv", ".sql"
}

HIGH_SIGNAL_DIRS = {
    "ops", "orchestrator", "quantum_ai_trading", "token_factory",
    "quantumai-usdt-v2", "usdt", "services", "stack", "tests", "tools", "scripts"
}

DEFAULT_EXCLUDE_NAMES = {
    ".git", ".hg", ".svn", "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache",
    ".idea", ".vscode", ".venv", "venv", "env", "dist", "build", ".next", ".nuxt",
    ".turbo", "coverage", ".coverage", ".gradle", ".terraform", ".serverless",
    ".aws-sam", ".cache", ".tox", ".eggs"
}

PERF_EXCLUDE_CANDIDATES = {
    "node_modules", "__pycache__", "pgdata", "tmp", "output", "_repo_research",
    "dist", "build", ".next", ".nuxt", ".turbo", ".cache", ".pytest_cache", ".mypy_cache"
}

CRITICAL_ENTRYPOINT_HINTS = {
    "Dockerfile", "docker-compose.yml", "compose.yml", "Makefile", "package.json",
    "pyproject.toml", "requirements.txt", ".env", "README.md", "README_PROD_OPS.md",
    "README_PROD_RUNBOOK.md", "quantumai_boot.sh", "run.sh", "run_all.sh", "wsgi.py"
}


def read_json(path: Path):
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def read_csv(path: Path):
    rows = []
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append(row)
    return rows


def safe_int(v, default=0):
    try:
        return int(v)
    except Exception:
        return default


def first_existing(paths):
    for p in paths:
        if p.exists():
            return p
    return None


def normalize_rel(path_str: str) -> str:
    return path_str.replace("\\", "/").strip()


def top_n(counter_obj, n=20):
    return counter_obj.most_common(n)


def pct(part, total):
    if total <= 0:
        return 0.0
    return round((part / total) * 100.0, 2)


def detect_area(rel_path: str) -> str:
    rel = normalize_rel(rel_path)
    head = rel.split("/", 1)[0]
    if head in HIGH_SIGNAL_DIRS:
        return head
    if rel.startswith("node_modules/"):
        return "node_modules"
    if rel.startswith("_repo_research/"):
        return "_repo_research"
    if rel.startswith("ios/"):
        return "ios"
    return "other"


def classify_file_usage(row: dict) -> str:
    rel = normalize_rel(row.get("relative_path", ""))
    role = (row.get("role") or "").strip().lower()
    suffix = (row.get("suffix") or "").strip().lower()

    if rel.startswith("ops/"):
        return "operasyon_hardening_repair"
    if rel.startswith("orchestrator/components/"):
        return "containerized_ai_component"
    if rel.startswith("orchestrator/metrics/"):
        return "metrics_exporter"
    if rel.startswith("quantum_ai_trading/"):
        return "ai_trading_module"
    if rel.startswith("token_factory/"):
        return "token_factory_module"
    if rel.startswith("tests/"):
        return "test_validation_suite"
    if rel.startswith("scripts/"):
        return "automation_runtime_script"
    if rel.startswith("stack/"):
        return "stack_gateway_or_dex"
    if rel.startswith("tools/etherscan/"):
        return "etherscan_tracking_tool"
    if rel.startswith("tools/profitability/"):
        return "profitability_analysis_tool"
    if rel.startswith("node_modules/"):
        return "vendor_dependency"
    if role == "docker_compose":
        return "container_orchestration"
    if role == "dockerfile":
        return "image_build_recipe"
    if role == "env_config":
        return "runtime_configuration"
    if role == "makefile":
        return "task_automation"
    if role == "python":
        return "python_source"
    if role == "shell":
        return "shell_automation"
    if role == "javascript_typescript":
        return "js_ts_source"
    if role == "plist":
        return "launch_configuration"
    if role == "html":
        return "report_or_ui_html"
    if suffix == ".log":
        return "runtime_log"
    if suffix in {".md", ".txt", ".rst"}:
        return "documentation"
    if suffix in {".csv", ".json"}:
        return "data_or_report"
    if suffix in {".pyc"}:
        return "compiled_cache"
    return "general_project_asset"


def detect_runtime_risk(row: dict) -> str:
    rel = normalize_rel(row.get("relative_path", ""))
    summary = (row.get("summary") or "").lower()
    name = Path(rel).name.lower()

    if ".bak." in rel or name.endswith(".bak"):
        return "stale_backup_shadowing"
    if rel.startswith("node_modules/"):
        return "low_runtime_priority_vendor"
    if rel.startswith("__pycache__/") or "/__pycache__/" in rel:
        return "compiled_cache_noise"
    if "scan_error" in (row.get("role") or "").lower():
        return "scan_failure"
    if "read_error" in summary or "syntaxerror" in summary:
        return "parse_or_read_failure"
    if name in {"docker-compose.yml", "compose.yml", "dockerfile", "package.json", "pyproject.toml"}:
        return "critical_runtime_manifest"
    if rel.startswith("ops/") and row.get("role") == "shell":
        return "high_impact_ops_script"
    if rel.startswith("tests/"):
        return "test_only"
    return "normal"


def analyze_inventory(repo_rows, dir_rows, summary_json, root_path: Path):
    total_files = safe_int(summary_json.get("file_count", 0), len(repo_rows))
    total_dirs = safe_int(summary_json.get("directory_count", 0), len(dir_rows))
    total_bytes = safe_int(summary_json.get("total_bytes", 0), sum(safe_int(r.get("size")) for r in repo_rows))

    role_counter = Counter()
    suffix_counter = Counter()
    area_counter = Counter()
    usage_counter = Counter()
    risk_counter = Counter()
    binary_counter = Counter()
    ext_bytes = Counter()
    area_bytes = Counter()
    backup_files = []
    logs_files = []
    html_files = []
    txt_files = []
    env_files = []
    entrypoint_candidates = []
    duplicate_names = Counter()
    duplicate_rel_by_name = defaultdict(list)
    service_candidates = defaultdict(list)

    for row in repo_rows:
        rel = normalize_rel(row.get("relative_path", ""))
        suffix = (row.get("suffix") or "<none>").strip() or "<none>"
        role = (row.get("role") or "unknown").strip()
        size = safe_int(row.get("size", 0))
        area = detect_area(rel)
        usage = classify_file_usage(row)
        risk = detect_runtime_risk(row)
        name = Path(rel).name

        role_counter[role] += 1
        suffix_counter[suffix] += 1
        area_counter[area] += 1
        usage_counter[usage] += 1
        risk_counter[risk] += 1
        ext_bytes[suffix] += size
        area_bytes[area] += size
        duplicate_names[name] += 1
        duplicate_rel_by_name[name].append(rel)

        if str(row.get("binary", "")).lower() == "true":
            binary_counter["binary"] += 1
        else:
            binary_counter["text_or_unknown"] += 1

        low_rel = rel.lower()
        if ".bak." in low_rel or low_rel.endswith(".bak"):
            backup_files.append(row)
        if suffix == ".log":
            logs_files.append(row)
        if suffix in {".html", ".htm"}:
            html_files.append(row)
        if suffix in {".txt", ".md", ".rst"}:
            txt_files.append(row)
        if name.startswith(".env") or suffix == ".env":
            env_files.append(row)
        if name in CRITICAL_ENTRYPOINT_HINTS:
            entrypoint_candidates.append(row)

        if low_rel.startswith("services/") or low_rel.startswith("stack/") or low_rel.startswith("orchestrator/components/"):
            service_key = "/".join(low_rel.split("/")[:3])
            service_candidates[service_key].append(rel)

    largest_dirs = sorted(dir_rows, key=lambda x: safe_int(x.get("bytes", 0)), reverse=True)[:40]
    largest_files = sorted(repo_rows, key=lambda x: safe_int(x.get("size", 0)), reverse=True)[:60]
    duplicate_hotspots = [(name, count, duplicate_rel_by_name[name][:12]) for name, count in duplicate_names.most_common(60) if count > 1]

    perf_exclude_hits = {}
    for candidate in PERF_EXCLUDE_CANDIDATES:
        perf_exclude_hits[candidate] = 0

    for drow in dir_rows:
        d = normalize_rel(drow.get("directory", ""))
        for candidate in PERF_EXCLUDE_CANDIDATES:
            if d == candidate or f"/{candidate}" in d:
                perf_exclude_hits[candidate] += safe_int(drow.get("files", 0))

    return {
        "summary": {
            "root": str(root_path),
            "generated_at": datetime.now().isoformat(timespec="seconds"),
            "total_files": total_files,
            "total_dirs": total_dirs,
            "total_bytes": total_bytes,
            "text_or_unknown_files": binary_counter["text_or_unknown"],
            "binary_files": binary_counter["binary"],
        },
        "counters": {
            "role_counter": dict(role_counter),
            "suffix_counter": dict(suffix_counter),
            "area_counter": dict(area_counter),
            "usage_counter": dict(usage_counter),
            "risk_counter": dict(risk_counter),
        },
        "top": {
            "largest_dirs": largest_dirs,
            "largest_files": largest_files,
            "duplicate_hotspots": duplicate_hotspots,
            "top_suffixes": top_n(suffix_counter, 40),
            "top_roles": top_n(role_counter, 40),
            "top_areas": top_n(area_counter, 40),
            "top_usages": top_n(usage_counter, 40),
            "top_risks": top_n(risk_counter, 40),
            "ext_bytes": top_n(ext_bytes, 40),
            "area_bytes": top_n(area_bytes, 40),
        },
        "collections": {
            "backup_files": backup_files[:200],
            "log_files": logs_files[:200],
            "html_files": html_files[:200],
            "txt_files": txt_files[:200],
            "env_files": env_files[:200],
            "entrypoint_candidates": entrypoint_candidates[:200],
            "service_candidates": {k: v[:30] for k, v in service_candidates.items()},
            "perf_exclude_hits": perf_exclude_hits,
        }
    }


def targeted_content_scan(root: Path, limit_per_type=1000):
    findings = {
        "logs": [],
        "html": [],
        "text": [],
        "forms_like_html": [],
        "metric_like_keywords": Counter(),
        "error_like_keywords": Counter(),
        "dependency_like_keywords": Counter(),
    }

    metric_patterns = [
        r"\bprometheus\b", r"\bgrafana\b", r"\bmetrics?\b", r"\bexporter\b",
        r"\bhealth\b", r"\bheartbeat\b", r"\blatency\b", r"\bthroughput\b",
        r"\bcpu\b", r"\bram\b", r"\bmemory\b", r"\bredis\b", r"\bpostgres\b",
        r"\bkafka\b", r"\bredpanda\b"
    ]
    error_patterns = [
        r"\berror\b", r"\bexception\b", r"\btraceback\b", r"\bfailed\b",
        r"\bsyntaxerror\b", r"\bconnection refused\b", r"\btimeout\b", r"\bdenied\b"
    ]
    dependency_patterns = [
        r"\brequirements?\b", r"\bpackage\.json\b", r"\bpyproject\b", r"\buv\.lock\b",
        r"\bpackage-lock\.json\b", r"\bDockerfile\b", r"\bdocker-compose\b"
    ]

    counts = {"logs": 0, "html": 0, "text": 0}

    for cur, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in DEFAULT_EXCLUDE_NAMES and d not in PERF_EXCLUDE_CANDIDATES]
        for fn in files:
            path = Path(cur) / fn
            suffix = path.suffix.lower()

            kind = None
            if suffix == ".log":
                kind = "logs"
            elif suffix in {".html", ".htm"}:
                kind = "html"
            elif suffix in {".txt", ".md", ".rst"}:
                kind = "text"

            if not kind:
                continue
            if counts[kind] >= limit_per_type:
                continue

            try:
                raw = path.read_text(encoding="utf-8", errors="replace")[:50000]
            except Exception:
                continue

            rel = str(path.relative_to(root))
            counts[kind] += 1
            first_line = ""
            for line in raw.splitlines():
                s = line.strip()
                if s:
                    first_line = s[:240]
                    break

            findings[kind].append({
                "relative_path": rel,
                "size": path.stat().st_size,
                "first_line": first_line
            })

            lower = raw.lower()

            for pat in metric_patterns:
                if re.search(pat, lower):
                    findings["metric_like_keywords"][pat] += 1
            for pat in error_patterns:
                if re.search(pat, lower):
                    findings["error_like_keywords"][pat] += 1
            for pat in dependency_patterns:
                if re.search(pat, lower):
                    findings["dependency_like_keywords"][pat] += 1

            if kind == "html" and re.search(r"<form\b|type=['\"](?:text|password|email|submit|hidden)", raw, re.I):
                findings["forms_like_html"].append(rel)

    findings["metric_like_keywords"] = dict(findings["metric_like_keywords"].most_common(30))
    findings["error_like_keywords"] = dict(findings["error_like_keywords"].most_common(30))
    findings["dependency_like_keywords"] = dict(findings["dependency_like_keywords"].most_common(30))
    return findings


def build_findings(analysis, content_scan):
    summary = analysis["summary"]
    top = analysis["top"]
    col = analysis["collections"]

    findings = []

    findings.append({
        "title": "Repo yap??s?? monorepo + operasyon + servis + vendor kar??????m??",
        "detail": (
            f"Toplam {summary['total_dirs']} dizin ve {summary['total_files']} dosya i??inde "
            f"??zellikle ops, orchestrator, token_factory, quantum_ai_trading, usdt ve vendor i??erikler birlikte bulunuyor. "
            "Bu, tek k??kte ??ok say??da ??al????ma modu ve ortam ba????ml??l?????? oldu??u anlam??na gelir."
        ),
        "impact": "y??ksek"
    })

    findings.append({
        "title": "Vendor/generate edilmi?? i??erik sinyal g??r??lt??s??n?? y??kseltiyor",
        "detail": (
            "node_modules, __pycache__, backup ve ????kt?? klas??rleri derin analizde operasyonel kodu g??lgeleme riski ta????yor. "
            f"Performans d????lama adaylar??n??n dosya y??k??: {col['perf_exclude_hits']}"
        ),
        "impact": "y??ksek"
    })

    findings.append({
        "title": "Ops klas??r?? y??ksek etkili",
        "detail": (
            "ops/ alt??nda compose hardening, recovery, launchagent, prod cutover, rollback, watch, health ve audit scriptleri bulunuyor; "
            "bu klas??r canl?? sistemi do??rudan etkileyebilecek komutlar i??eriyor."
        ),
        "impact": "y??ksek"
    })

    findings.append({
        "title": "Servis tekrar?? ve shadowing riski var",
        "detail": (
            "Ayn?? i?? alan??n?? temsil eden birden fazla k??k g??z??k??yor: quantumai-usdt-v2, usdt, services/quantumai_usdt_v2, stack/dex, orchestrator/components/* . "
            "Bu, hangi entrypoint'in kanonik oldu??u belirsizle??ti??inde bak??m ve deploy hatas?? ??retir."
        ),
        "impact": "y??ksek"
    })

    findings.append({
        "title": "Rapor ??retimi ba??ar??l?? fakat art??k ikinci kademe ayr????t??rma gerekli",
        "detail": (
            f"??lk a??ama tarama tamamland??; en b??y??k roller: {top['top_roles'][:10]}. "
            "Sonraki ad??m ??al????ma/??al????mama nedeni, ba????ml??l??k ve performans ??nerilerini ayr?? raporlara b??lmek olmal??."
        ),
        "impact": "orta"
    })

    findings.append({
        "title": "HTML/TXT/LOG incelemesi ayr??ca de??erli",
        "detail": (
            f"Targeted scan sonu??lar??: log={len(content_scan['logs'])}, html={len(content_scan['html'])}, "
            f"text={len(content_scan['text'])}, form-benzeri html={len(content_scan['forms_like_html'])}."
        ),
        "impact": "orta"
    })

    findings.append({
        "title": "Risk kategorileri g??r??n??r hale getirildi",
        "detail": f"En yayg??n runtime risk k??meleri: {top['top_risks'][:15]}",
        "impact": "orta"
    })

    return findings


def performance_recommendations(analysis):
    perf = analysis["collections"]["perf_exclude_hits"]
    largest_dirs = analysis["top"]["largest_dirs"][:15]
    largest_files = analysis["top"]["largest_files"][:20]

    recs = [
        {
            "priority": "P1",
            "action": "Derin i??erik analizinde node_modules, __pycache__, pgdata, tmp, output ve _repo_research klas??rlerini varsay??lan d????la",
            "reason": f"D????lama potansiyeli dosya y??k??: {perf}"
        },
        {
            "priority": "P1",
            "action": "Vendor/artifact i??in metadata-only mod kullan; i??erik parse etme",
            "reason": "Ger??ek uygulama kodunu ??ne ????kar??r, CSV/JSON boyutunu ve parse s??resini d??????r??r"
        },
        {
            "priority": "P1",
            "action": "Tek kanonik servis yolu belirle: usdt / quantumai-usdt-v2 / services/quantumai_usdt_v2",
            "reason": "Shadow deploy ve bak??m ??ak????mas??n?? azalt??r"
        },
        {
            "priority": "P2",
            "action": "ops/ klas??r??nde destructive/high-impact scriptleri ayr?? whitelist ile etiketle",
            "reason": "Canl?? ortamda yanl???? ??al????t??rma riskini d??????r??r"
        },
        {
            "priority": "P2",
            "action": "Backup ve .bak dosyalar??n?? ana rapordan ayr?? indekse ta????",
            "reason": "Kod taban??nda eski s??r??m g??lgelemesini azalt??r"
        },
        {
            "priority": "P2",
            "action": "requirements/package-lock/uv.lock/pyproject/package.json kaynaklar??n?? tek ba????ml??l??k matrisi raporuna ba??la",
            "reason": "Ba????ml??l??k eksikli??i ve s??r??m tutars??zl?????? g??r??n??r olur"
        },
        {
            "priority": "P3",
            "action": "B??y??k klas??rler i??in incremental tarama state dosyas?? kullan",
            "reason": "mtime/size de??i??mediyse yeniden parse etmeyerek tekrar taramay?? k??salt??r"
        },
    ]

    return {
        "recommendations": recs,
        "largest_dirs": largest_dirs,
        "largest_files": largest_files,
    }


def operational_assessment(analysis):
    usage_counter = Counter(analysis["counters"]["usage_counter"])
    risk_counter = Counter(analysis["counters"]["risk_counter"])
    area_counter = Counter(analysis["counters"]["area_counter"])

    what_it_is = [
        "Repo; container orkestrasyonu, operasyon/hardening scriptleri, AI servis bile??enleri, trading mod??lleri, token factory ve USDT servislerinden olu??an karma bir platform yap??s??d??r.",
        f"Alan da????l??m?? ??ne ????kan k??meler: {area_counter.most_common(12)}",
        f"Kullan??m s??n??flar?? ??ne ????kanlar: {usage_counter.most_common(12)}",
    ]

    how_to_use = [
        "??nce kanonik entrypoint???leri belirleyin: README, Makefile, docker-compose/compose, run.sh, quantumai_boot.sh, ops runbook dosyalar??.",
        "??kinci olarak servisleri ???? seviyeye ay??r??n: canl?? servis, yard??mc?? ara??, vendor/artefact.",
        "??????nc?? olarak ba????ml??l??k audit hatt??n?? Python/Node/Docker olarak ay??r??n.",
    ]

    working_assumptions = [
        "??al????an k??s??mlar b??y??k olas??l??kla compose, Dockerfile, ops recovery scriptleri, orchestrator component image recipe???leri ve Python servis entrypoint???leridir.",
        "Test dosyalar?? ve metrics/exporter mod??lleri sa??l??k kontrol?? i??in referans olarak kullan??labilir.",
    ]

    nonworking_risks = [
        "Ayn?? servis alan??n?? temsil eden tekrar eden klas??rler yanl???? build/deploy hedefi se??ilmesine yol a??abilir.",
        "Backup ve stale dosyalar ger??ek entrypoint???i g??lgeleyebilir.",
        f"Runtime risk da????l??m??: {risk_counter.most_common(12)}",
    ]

    return {
        "what_it_is": what_it_is,
        "how_to_use": how_to_use,
        "working_assumptions": working_assumptions,
        "nonworking_risks": nonworking_risks,
    }


def render_markdown(analysis, content_scan, findings, perf, op_assessment):
    s = analysis["summary"]
    lines = []
    lines.append("# QuantumAI Deep Repo Assessment")
    lines.append("")
    lines.append("## 1. Genel ??zet")
    lines.append("")
    lines.append(f"- K??k dizin: `{s['root']}`")
    lines.append(f"- ??retim zaman??: `{s['generated_at']}`")
    lines.append(f"- Toplam dizin: `{s['total_dirs']}`")
    lines.append(f"- Toplam dosya: `{s['total_files']}`")
    lines.append(f"- Toplam boyut: `{s['total_bytes']}` byte")
    lines.append(f"- Text/unknown: `{s['text_or_unknown_files']}`")
    lines.append(f"- Binary: `{s['binary_files']}`")
    lines.append("")

    lines.append("## 2. Bu Sistem Ne ????e Yar??yor")
    lines.append("")
    for item in op_assessment["what_it_is"]:
        lines.append(f"- {item}")
    lines.append("")

    lines.append("## 3. Nas??l Kullan??l??r")
    lines.append("")
    for item in op_assessment["how_to_use"]:
        lines.append(f"- {item}")
    lines.append("")

    lines.append("## 4. ??al??????yorsa Nas??l ??al??????yor")
    lines.append("")
    for item in op_assessment["working_assumptions"]:
        lines.append(f"- {item}")
    lines.append("")

    lines.append("## 5. ??al????m??yorsa Muhtemel Nedenler")
    lines.append("")
    for item in op_assessment["nonworking_risks"]:
        lines.append(f"- {item}")
    lines.append("")

    lines.append("## 6. Derin Bulgular")
    lines.append("")
    for item in findings:
        lines.append(f"- [{item['impact'].upper()}] {item['title']}: {item['detail']}")
    lines.append("")

    lines.append("## 7. Rol Da????l??m??")
    lines.append("")
    for k, v in analysis["top"]["top_roles"]:
        lines.append(f"- `{k}`: {v}")
    lines.append("")

    lines.append("## 8. Kullan??m S??n??flar??")
    lines.append("")
    for k, v in analysis["top"]["top_usages"]:
        lines.append(f"- `{k}`: {v}")
    lines.append("")

    lines.append("## 9. Alan Bazl?? Yo??unluk")
    lines.append("")
    for k, v in analysis["top"]["top_areas"]:
        lines.append(f"- `{k}`: {v}")
    lines.append("")

    lines.append("## 10. En B??y??k Dizinler")
    lines.append("")
    for row in analysis["top"]["largest_dirs"][:30]:
        lines.append(f"- `{row.get('directory')}` | files={row.get('files')} | bytes={row.get('bytes')} | roles={row.get('top_roles')}")
    lines.append("")

    lines.append("## 11. En B??y??k Dosyalar")
    lines.append("")
    for row in analysis["top"]["largest_files"][:40]:
        lines.append(f"- `{row.get('relative_path')}` | size={row.get('size')} | role={row.get('role')} | summary={row.get('summary')}")
    lines.append("")

    lines.append("## 12. Backup / Shadowing Adaylar??")
    lines.append("")
    for row in analysis["collections"]["backup_files"][:80]:
        lines.append(f"- `{row.get('relative_path')}`")
    lines.append("")

    lines.append("## 13. HTML / Form / Log / Text Taramas??")
    lines.append("")
    lines.append(f"- Log ??rnekleri: {len(content_scan['logs'])}")
    lines.append(f"- HTML ??rnekleri: {len(content_scan['html'])}")
    lines.append(f"- Text ??rnekleri: {len(content_scan['text'])}")
    lines.append(f"- Form benzeri HTML say??s??: {len(content_scan['forms_like_html'])}")
    lines.append(f"- Metric benzeri keyword yo??unlu??u: {content_scan['metric_like_keywords']}")
    lines.append(f"- Error benzeri keyword yo??unlu??u: {content_scan['error_like_keywords']}")
    lines.append(f"- Dependency benzeri keyword yo??unlu??u: {content_scan['dependency_like_keywords']}")
    lines.append("")

    lines.append("## 14. %40 Performans ??yile??tirme Plan??")
    lines.append("")
    for rec in perf["recommendations"]:
        lines.append(f"- [{rec['priority']}] {rec['action']} ??? {rec['reason']}")
    lines.append("")

    lines.append("## 15. Sonu??")
    lines.append("")
    lines.append("- Bu repo do??rudan tek par??a bir uygulama de??il; operasyon, deploy, AI servis, token/usdt ve vendor i??eriklerin kar??????k oldu??u ??ok ama??l?? bir platform a??ac??.")
    lines.append("- En b??y??k kazan??: d????lama politikas?? + kanonik entrypoint belirleme + ba????ml??l??k denetimini ayr?? katmanlara ay??rma.")
    lines.append("- Bu derin rapor, ilk taramadan sonra ikinci kademe karar destek raporudur.")
    lines.append("")
    return "\n".join(lines)


def render_html_from_md(md_text: str) -> str:
    return f"""<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>QuantumAI Deep Repo Assessment</title>
<style>
body{{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica,Arial,sans-serif;background:#0b1020;color:#e6edf3;max-width:1500px;margin:0 auto;padding:24px;line-height:1.55}}
pre{{white-space:pre-wrap;word-break:break-word;background:#111827;padding:18px;border-radius:12px;border:1px solid #334155}}
</style>
</head>
<body>
<pre>{html.escape(md_text)}</pre>
</body>
</html>"""


def main():
    ap = argparse.ArgumentParser(description="??lk repo tarama ????kt??lar??ndan derin ikinci kademe analiz ??retir.")
    ap.add_argument("--root", required=True, help="Repo k??k dizini")
    ap.add_argument("--reports-dir", required=True, help="??lk tarama raporlar??n??n bulundu??u klas??r")
    ap.add_argument("--out", required=True, help="????kt?? klas??r??")
    args = ap.parse_args()

    root = Path(args.root).expanduser().resolve()
    reports_dir = Path(args.reports_dir).expanduser().resolve()
    out = Path(args.out).expanduser().resolve()
    out.mkdir(parents=True, exist_ok=True)

    repo_inventory = reports_dir / "repo_inventory.csv"
    directory_inventory = reports_dir / "directory_inventory.csv"
    repo_summary = reports_dir / "repo_summary.json"
    report_md = reports_dir / "repo_research_report.md"
    report_html = reports_dir / "repo_research_report.html"

    required = [repo_inventory, directory_inventory, repo_summary, report_md, report_html]
    missing = [str(p) for p in required if not p.exists()]
    if missing:
        print("EKS??K_RAPOR_DOSYALARI:")
        for item in missing:
            print(item)
        sys.exit(2)

    repo_rows = read_csv(repo_inventory)
    dir_rows = read_csv(directory_inventory)
    summary_json = read_json(repo_summary)

    analysis = analyze_inventory(repo_rows, dir_rows, summary_json, root)
    content_scan = targeted_content_scan(root, limit_per_type=1200)
    findings = build_findings(analysis, content_scan)
    perf = performance_recommendations(analysis)
    op_assessment = operational_assessment(analysis)

    md = render_markdown(analysis, content_scan, findings, perf, op_assessment)
    html_text = render_html_from_md(md)

    out_md = out / "deep_repo_assessment.md"
    out_html = out / "deep_repo_assessment.html"
    out_json = out / "deep_repo_assessment.json"
    out_findings_csv = out / "deep_repo_findings.csv"

    out_md.write_text(md, encoding="utf-8")
    out_html.write_text(html_text, encoding="utf-8")

    with out_json.open("w", encoding="utf-8") as f:
        json.dump({
            "analysis": analysis,
            "content_scan": content_scan,
            "findings": findings,
            "performance": perf,
            "operational_assessment": op_assessment
        }, f, ensure_ascii=False, indent=2)

    with out_findings_csv.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["impact", "title", "detail"])
        writer.writeheader()
        for item in findings:
            writer.writerow({
                "impact": item["impact"],
                "title": item["title"],
                "detail": item["detail"]
            })

    print(f"DEEP_MD:{out_md}")
    print(f"DEEP_HTML:{out_html}")
    print(f"DEEP_JSON:{out_json}")
    print(f"FINDINGS_CSV:{out_findings_csv}")
    print(f"TOTAL_DIRS:{analysis['summary']['total_dirs']}")
    print(f"TOTAL_FILES:{analysis['summary']['total_files']}")
    print(f"TARGETED_LOGS:{len(content_scan['logs'])}")
    print(f"TARGETED_HTML:{len(content_scan['html'])}")
    print(f"TARGETED_TEXT:{len(content_scan['text'])}")
    print("STATUS:OK")


if __name__ == "__main__":
    main()
