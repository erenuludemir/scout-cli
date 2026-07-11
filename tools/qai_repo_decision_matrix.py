#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import csv
import html
import json
import sys
from collections import Counter, defaultdict
from datetime import datetime
from pathlib import Path

SAFE_OPS_HINTS = (
    "health", "summary", "report", "audit", "validate", "check", "smoke", "digest", "inside_logs"
)
RECOVERY_OPS_HINTS = (
    "repair", "fix", "heal", "rollback", "resilience", "recover", "restore", "finalize", "hardening"
)
DESTRUCTIVE_OPS_HINTS = (
    "prod_cutover", "cutover", "shutdown", "rotate", "bootstrap", "install_launchagent", "apply", "rewrite"
)

CANONICAL_SERVICE_RULES = {
    "usdt_service": [
        "quantumai-usdt-v2",
        "services/quantumai_usdt_v2",
        "usdt",
    ],
    "token_factory": [
        "token_factory",
    ],
    "ai_trading": [
        "quantum_ai_trading",
    ],
    "orchestrator": [
        "orchestrator",
    ],
    "ops": [
        "ops",
    ],
    "stack": [
        "stack",
    ],
}

PERF_EXCLUDE_FINAL = [
    "node_modules",
    "__pycache__",
    "pgdata",
    "tmp",
    "output",
    "_repo_research",
    "dist",
    "build",
    ".next",
    ".nuxt",
    ".turbo",
    ".cache",
    ".pytest_cache",
    ".mypy_cache",
]

DEPENDENCY_FILES = {
    "python": [
        "requirements.txt",
        "requirements-dev.txt",
        "requirements-ai-token.txt",
        "requirements-ai-trading.txt",
        "requirements-token-factory.txt",
        "constraints.txt",
        "pyproject.toml",
        "uv.lock",
    ],
    "node": [
        "package.json",
        "package-lock.json",
        "pnpm-lock.yaml",
        "yarn.lock",
        "skills-lock.json",
    ],
    "docker": [
        "Dockerfile",
        "Dockerfile.apps",
        "docker-compose.yml",
        "compose.yml",
        "stack/docker-compose.yml",
    ],
    "apple": [
        ".xcodeproj",
        ".xcworkspace",
        ".plist",
        "xcodebuild.sh",
    ],
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


def normalize_rel(path_str: str) -> str:
    return str(path_str).replace("\\", "/").strip()


def detect_ops_risk(rel_path: str) -> str:
    low = normalize_rel(rel_path).lower()
    if not low.startswith("ops/"):
        return "not_ops"
    name = Path(low).name
    if any(h in name for h in DESTRUCTIVE_OPS_HINTS):
        return "destructive"
    if any(h in name for h in RECOVERY_OPS_HINTS):
        return "recovery"
    if any(h in name for h in SAFE_OPS_HINTS):
        return "safe"
    return "review"


def collect_repo_state(root: Path, repo_inventory_rows, dir_inventory_rows, deep_json):
    inv_by_path = {}
    by_dir = defaultdict(list)
    by_name = defaultdict(list)
    backup_candidates = []
    pycache_candidates = []
    vendor_candidates = []
    service_paths = defaultdict(list)
    dependency_hits = defaultdict(list)
    ops_scripts = []
    dockerfiles = []
    compose_files = []
    python_entrypoints = []
    shell_entrypoints = []
    readmes = []
    launch_configs = []
    tests = []
    largest_dirs = sorted(dir_inventory_rows, key=lambda r: safe_int(r.get("bytes", 0)), reverse=True)
    largest_files = sorted(repo_inventory_rows, key=lambda r: safe_int(r.get("size", 0)), reverse=True)

    for row in repo_inventory_rows:
        rel = normalize_rel(row.get("relative_path", ""))
        inv_by_path[rel] = row
        by_dir[str(Path(rel).parent)].append(row)
        by_name[Path(rel).name].append(rel)

        low = rel.lower()
        name = Path(rel).name
        suffix = (row.get("suffix") or "").lower()
        role = (row.get("role") or "").lower()

        if ".bak." in low or low.endswith(".bak"):
            backup_candidates.append(rel)
        if "/__pycache__/" in low or low.startswith("__pycache__/") or suffix == ".pyc":
            pycache_candidates.append(rel)
        if low.startswith("node_modules/"):
            vendor_candidates.append(rel)

        if low.startswith("quantumai-usdt-v2/") or low.startswith("usdt/") or low.startswith("services/quantumai_usdt_v2/"):
            service_paths["usdt_service"].append(rel)
        if low.startswith("token_factory/"):
            service_paths["token_factory"].append(rel)
        if low.startswith("quantum_ai_trading/"):
            service_paths["ai_trading"].append(rel)
        if low.startswith("orchestrator/"):
            service_paths["orchestrator"].append(rel)
        if low.startswith("ops/"):
            service_paths["ops"].append(rel)
        if low.startswith("stack/"):
            service_paths["stack"].append(rel)

        if low.startswith("ops/") and suffix in {".sh", ".py", ".md"}:
            ops_scripts.append({
                "relative_path": rel,
                "risk": detect_ops_risk(rel),
                "role": role,
                "summary": row.get("summary", ""),
            })

        if name == "Dockerfile" or name.startswith("Dockerfile."):
            dockerfiles.append(rel)
        if name in {"docker-compose.yml", "compose.yml", "compose.yaml", "docker-compose.yaml"}:
            compose_files.append(rel)
        if suffix == ".py" and name in {"main.py", "app.py", "wsgi.py"}:
            python_entrypoints.append(rel)
        if suffix in {".sh", ".bash", ".zsh"} and name in {"run.sh", "run_all.sh", "start_all.sh", "quantumai_boot.sh"}:
            shell_entrypoints.append(rel)
        if name.lower().startswith("readme"):
            readmes.append(rel)
        if suffix == ".plist":
            launch_configs.append(rel)
        if low.startswith("tests/"):
            tests.append(rel)

        for eco, patterns in DEPENDENCY_FILES.items():
            for pat in patterns:
                pat_low = pat.lower()
                if pat.startswith("."):
                    if low.endswith(pat_low):
                        dependency_hits[eco].append(rel)
                else:
                    if name == pat or low.endswith("/" + pat_low) or pat_low in low:
                        dependency_hits[eco].append(rel)

    duplicate_names = []
    for name, paths in by_name.items():
        if len(paths) > 1:
            duplicate_names.append({
                "name": name,
                "count": len(paths),
                "paths": sorted(paths)[:20]
            })
    duplicate_names.sort(key=lambda x: (-x["count"], x["name"]))

    return {
        "root": str(root),
        "inventory_count": len(repo_inventory_rows),
        "directory_count": len(dir_inventory_rows),
        "inv_by_path": inv_by_path,
        "by_dir": by_dir,
        "service_paths": {k: sorted(v) for k, v in service_paths.items()},
        "backup_candidates": sorted(set(backup_candidates)),
        "pycache_candidates": sorted(set(pycache_candidates)),
        "vendor_candidates": sorted(set(vendor_candidates)),
        "ops_scripts": sorted(ops_scripts, key=lambda x: (x["risk"], x["relative_path"])),
        "dockerfiles": sorted(set(dockerfiles)),
        "compose_files": sorted(set(compose_files)),
        "python_entrypoints": sorted(set(python_entrypoints)),
        "shell_entrypoints": sorted(set(shell_entrypoints)),
        "readmes": sorted(set(readmes)),
        "launch_configs": sorted(set(launch_configs)),
        "tests": sorted(set(tests)),
        "dependency_hits": {k: sorted(set(v)) for k, v in dependency_hits.items()},
        "largest_dirs": largest_dirs[:100],
        "largest_files": largest_files[:100],
        "duplicate_names": duplicate_names[:200],
        "deep_analysis": deep_json.get("analysis", {}),
        "deep_findings": deep_json.get("findings", []),
        "deep_perf": deep_json.get("performance", {}),
    }


def choose_canonical_service(service_key: str, paths):
    candidates = CANONICAL_SERVICE_RULES.get(service_key, [])
    counts = Counter()
    for rel in paths:
        nrel = normalize_rel(rel)
        for cand in candidates:
            if nrel.startswith(cand + "/") or nrel == cand:
                counts[cand] += 1
    if counts:
        chosen = counts.most_common(1)[0][0]
    elif candidates:
        chosen = candidates[0]
    else:
        chosen = service_key
    alternates = [c for c in candidates if c != chosen]
    return {
        "service_key": service_key,
        "chosen_canonical": chosen,
        "alternates": alternates,
        "evidence_count": sum(counts.values()) if counts else len(paths),
        "reasons": [
            f"Repo içinde {service_key} alanına ait çoklu yol tespit edildi.",
            f"Kanonik yol olarak `{chosen}` seçildi.",
            "Karar ölçütü: dizin yoğunluğu, isim tutarlılığı ve servis merkeziliği."
        ]
    }


def build_service_decisions(state):
    decisions = []
    for service_key, paths in state["service_paths"].items():
        if not paths:
            continue
        decision = choose_canonical_service(service_key, paths)
        duplicate_scope = []
        chosen = decision["chosen_canonical"]
        for rel in paths:
            top = normalize_rel(rel).split("/", 2)
            if top:
                root_dir = "/".join(top[:2]) if len(top) >= 2 and top[0] == "services" else top[0]
                if root_dir != chosen and root_dir not in duplicate_scope:
                    duplicate_scope.append(root_dir)
        decision["duplicate_roots"] = sorted(set(duplicate_scope))
        decision["recommended_actions"] = [
            f"`{chosen}` kanonik servis yolu olarak tutulmalı.",
            "Alternatif köklerdeki entrypoint, Dockerfile, requirements ve app/main dosyaları diff ile karşılaştırılmalı.",
            "Aynı işlevi gören alternatif klasörler `_legacy/` veya `_archive_backups/` altına taşınmalı."
        ]
        decisions.append(decision)
    return decisions


def build_backup_archive_plan(state):
    archive_map = []
    for rel in state["backup_candidates"][:500]:
        archive_map.append({
            "src": rel,
            "dst": "_archive_backups/" + rel.replace("/", "__")
        })
    return archive_map


def build_ops_matrix(state):
    safe_items = []
    recovery_items = []
    destructive_items = []
    review_items = []
    for item in state["ops_scripts"]:
        risk = item["risk"]
        if risk == "safe":
            safe_items.append(item)
        elif risk == "recovery":
            recovery_items.append(item)
        elif risk == "destructive":
            destructive_items.append(item)
        else:
            review_items.append(item)
    return {
        "safe": safe_items[:200],
        "recovery": recovery_items[:200],
        "destructive": destructive_items[:200],
        "review": review_items[:200],
    }


def build_dependency_audit_plan(state):
    root = state["root"]
    plans = []
    python_targets = state["dependency_hits"].get("python", [])
    node_targets = state["dependency_hits"].get("node", [])
    docker_targets = state["dependency_hits"].get("docker", [])
    apple_targets = state["dependency_hits"].get("apple", [])

    if python_targets:
        plans.append({
            "ecosystem": "python",
            "purpose": "Python bağımlılık açıkları ve sürüm tutarlılığı",
            "commands": [
                f'cd "{root}" && python3 -m pip install --upgrade pip pip-audit',
                f'cd "{root}" && python3 -m pip_audit || true'
            ],
            "evidence": python_targets[:50]
        })

    if node_targets:
        plans.append({
            "ecosystem": "node",
            "purpose": "Node bağımlılık açıkları ve lock dosyası kontrolü",
            "commands": [
                f'cd "{root}" && npm audit --audit-level=high || true',
                f'cd "{root}" && npm outdated || true'
            ],
            "evidence": node_targets[:50]
        })

    if docker_targets:
        plans.append({
            "ecosystem": "docker",
            "purpose": "Docker image/build recipe ve scout/sbom kontrolü",
            "commands": [
                f'cd "{root}" && docker scout quickview . || true',
                f'cd "{root}" && docker scout cves . || true'
            ],
            "evidence": docker_targets[:50]
        })

    if apple_targets:
        plans.append({
            "ecosystem": "apple",
            "purpose": "Apple/Xcode çalışma bileşenleri ve yapılandırma gözden geçirme",
            "commands": [
                f'cd "{root}" && find . -name "*.plist" -maxdepth 6 | sort',
                f'cd "{root}" && [ -x "./xcodebuild.sh" ] && bash "./xcodebuild.sh" || true'
            ],
            "evidence": apple_targets[:50]
        })

    return plans


def build_exclusion_plan(state):
    hit_counts = Counter()
    for _ in state["vendor_candidates"]:
        hit_counts["node_modules"] += 1
    for _ in state["pycache_candidates"]:
        hit_counts["__pycache__"] += 1

    for drow in state["largest_dirs"]:
        d = normalize_rel(drow.get("directory", ""))
        for excl in PERF_EXCLUDE_FINAL:
            if d == excl or f"/{excl}" in d:
                hit_counts[excl] += safe_int(drow.get("files", 0))

    plan = []
    for excl in PERF_EXCLUDE_FINAL:
        plan.append({
            "name": excl,
            "estimated_hit_files": safe_int(hit_counts.get(excl, 0)),
            "action": "deep_scan_exclude",
            "reason": "performans ve sinyal-gürültü optimizasyonu"
        })
    return plan


def build_runbook_actions(state, service_decisions, ops_matrix, exclusion_plan, backup_plan, audit_plan):
    actions = [
        {
            "phase": "F1",
            "title": "Tarama dışlama politikasını kalıcılaştır",
            "detail": "node_modules, __pycache__, pgdata, tmp, output, _repo_research ve diğer artifact klasörlerini varsayılan dışla.",
            "priority": "critical"
        },
        {
            "phase": "F2",
            "title": "Kanonik servis yollarını sabitle",
            "detail": "USDT, token factory, ai_trading, orchestrator ve stack için tek kök seç ve diğer kökleri legacy olarak işaretle.",
            "priority": "critical"
        },
        {
            "phase": "F3",
            "title": "ops script risk zoneları oluştur",
            "detail": "ops/safe, ops/recovery, ops/destructive, ops/review sınıflandırmasına göre taşı veya en azından envanter üret.",
            "priority": "high"
        },
        {
            "phase": "F4",
            "title": "Backup ve stale dosyaları arşive taşı",
            "detail": f"Toplam backup adayı: {len(backup_plan)}",
            "priority": "high"
        },
        {
            "phase": "F5",
            "title": "Bağımlılık audit zinciri çalıştır",
            "detail": f"Audit plan sayısı: {len(audit_plan)}",
            "priority": "high"
        },
        {
            "phase": "F6",
            "title": "Entrypoint ve manifest eşleşmesini doğrula",
            "detail": f"Compose={len(state['compose_files'])}, Dockerfile={len(state['dockerfiles'])}, Python entrypoint={len(state['python_entrypoints'])}, Shell entrypoint={len(state['shell_entrypoints'])}",
            "priority": "high"
        },
        {
            "phase": "F7",
            "title": "Duplicate dosya adı hotspot’larını incele",
            "detail": f"Duplicate hotspot sayısı: {len(state['duplicate_names'])}",
            "priority": "medium"
        },
        {
            "phase": "F8",
            "title": "Test ve sağlık kontrolü ile servis doğrulama",
            "detail": f"Test dosyası sayısı: {len(state['tests'])}",
            "priority": "medium"
        },
    ]

    destructive_count = len(ops_matrix["destructive"])
    if destructive_count > 0:
        actions.append({
            "phase": "F9",
            "title": "Yüksek etkili script onay kapısı",
            "detail": f"Destructive/review script sayısı: {destructive_count + len(ops_matrix['review'])}",
            "priority": "critical"
        })

    return actions


def build_shell_commands(state, service_decisions, backup_plan, exclusion_plan, audit_plan):
    root = state["root"]
    cmds = [
        f'cd "{root}"',
        'mkdir -p "_repo_research/decision_matrix" "_archive_backups"'
    ]

    for dec in service_decisions:
        chosen = dec["chosen_canonical"]
        for alt in dec["duplicate_roots"]:
            if alt and alt != chosen:
                cmds.append(f'printf "%s\\n" "KARAR::{dec["service_key"]}::CANONICAL={chosen}::ALT={alt}"')

    if backup_plan:
        cmds.append(f'printf "%s\\n" "BACKUP_ADAYI_SAYISI={len(backup_plan)}"')

    if exclusion_plan:
        excl = " ".join(sorted(set(item["name"] for item in exclusion_plan)))
        cmds.append(f'printf "%s\\n" "DERIN_TARAMA_DISLA={excl}"')

    for plan in audit_plan:
        cmds.extend(plan["commands"])

    return cmds


def render_markdown(state, service_decisions, backup_plan, ops_matrix, audit_plan, exclusion_plan, runbook_actions, shell_commands):
    lines = []
    lines.append("# QAI Repo Decision Matrix")
    lines.append("")
    lines.append("## 1. Genel Durum")
    lines.append("")
    lines.append(f"- Kök dizin: `{state['root']}`")
    lines.append(f"- Toplam dosya: `{state['inventory_count']}`")
    lines.append(f"- Toplam dizin: `{state['directory_count']}`")
    lines.append(f"- Üretim zamanı: `{datetime.now().isoformat(timespec='seconds')}`")
    lines.append("")

    lines.append("## 2. Kanonik Servis Kararları")
    lines.append("")
    for dec in service_decisions:
        lines.append(f"- Servis: `{dec['service_key']}`")
        lines.append(f"  - Kanonik: `{dec['chosen_canonical']}`")
        lines.append(f"  - Alternatifler: {', '.join(dec['alternates']) if dec['alternates'] else '-'}")
        lines.append(f"  - Duplicate root adayları: {', '.join(dec['duplicate_roots']) if dec['duplicate_roots'] else '-'}")
        for reason in dec["reasons"]:
            lines.append(f"  - Gerekçe: {reason}")
        for action in dec["recommended_actions"]:
            lines.append(f"  - Aksiyon: {action}")
    lines.append("")

    lines.append("## 3. Backup / Stale Arşiv Planı")
    lines.append("")
    lines.append(f"- Toplam aday: `{len(backup_plan)}`")
    for item in backup_plan[:80]:
        lines.append(f"- `{item['src']}` -> `{item['dst']}`")
    lines.append("")

    lines.append("## 4. Ops Risk Matrisi")
    lines.append("")
    lines.append(f"- Safe: `{len(ops_matrix['safe'])}`")
    lines.append(f"- Recovery: `{len(ops_matrix['recovery'])}`")
    lines.append(f"- Destructive: `{len(ops_matrix['destructive'])}`")
    lines.append(f"- Review: `{len(ops_matrix['review'])}`")
    lines.append("")
    lines.append("### 4.1 Destructive")
    for item in ops_matrix["destructive"][:100]:
        lines.append(f"- `{item['relative_path']}` | {item['summary']}")
    lines.append("")
    lines.append("### 4.2 Recovery")
    for item in ops_matrix["recovery"][:100]:
        lines.append(f"- `{item['relative_path']}` | {item['summary']}")
    lines.append("")
    lines.append("### 4.3 Safe")
    for item in ops_matrix["safe"][:100]:
        lines.append(f"- `{item['relative_path']}` | {item['summary']}")
    lines.append("")
    lines.append("### 4.4 Review")
    for item in ops_matrix["review"][:100]:
        lines.append(f"- `{item['relative_path']}` | {item['summary']}")
    lines.append("")

    lines.append("## 5. Dışlama Politikası")
    lines.append("")
    for item in exclusion_plan:
        lines.append(f"- `{item['name']}` | tahmini_etki={item['estimated_hit_files']} | {item['reason']}")
    lines.append("")

    lines.append("## 6. Bağımlılık Audit Planı")
    lines.append("")
    for plan in audit_plan:
        lines.append(f"- Ekosistem: `{plan['ecosystem']}`")
        lines.append(f"  - Amaç: {plan['purpose']}")
        lines.append(f"  - Kanıt dosyaları: {', '.join(plan['evidence'][:12]) if plan['evidence'] else '-'}")
        for cmd in plan["commands"]:
            lines.append(f"  - Komut: `{cmd}`")
    lines.append("")

    lines.append("## 7. Runbook Aksiyonları")
    lines.append("")
    for item in runbook_actions:
        lines.append(f"- [{item['priority'].upper()}] `{item['phase']}` {item['title']} — {item['detail']}")
    lines.append("")

    lines.append("## 8. Duplicate Dosya Adı Hotspotları")
    lines.append("")
    for item in state["duplicate_names"][:80]:
        lines.append(f"- `{item['name']}` | count={item['count']} | örnekler={', '.join(item['paths'][:8])}")
    lines.append("")

    lines.append("## 9. Büyük Dizinler")
    lines.append("")
    for row in state["largest_dirs"][:40]:
        lines.append(f"- `{row.get('directory')}` | files={row.get('files')} | bytes={row.get('bytes')} | roles={row.get('top_roles')}")
    lines.append("")

    lines.append("## 10. Büyük Dosyalar")
    lines.append("")
    for row in state["largest_files"][:40]:
        lines.append(f"- `{row.get('relative_path')}` | size={row.get('size')} | role={row.get('role')} | summary={row.get('summary')}")
    lines.append("")

    lines.append("## 11. Kabuk Komutları")
    lines.append("")
    for cmd in shell_commands:
        lines.append(f"- `{cmd}`")
    lines.append("")

    lines.append("## 12. Son Karar")
    lines.append("")
    lines.append("- Repo tek parça bir uygulama değil; operasyonel monorepo + servis tekrarları + vendor/artifact yoğunluğu içeriyor.")
    lines.append("- İlk zorunlu aksiyon: dışlama politikası.")
    lines.append("- İkinci zorunlu aksiyon: kanonik servis yolunu sabitleme.")
    lines.append("- Üçüncü zorunlu aksiyon: ops script risk katmanlama.")
    lines.append("- Dördüncü zorunlu aksiyon: backup/stale arşivleme.")
    lines.append("")
    return "\n".join(lines)


def render_html(md_text: str) -> str:
    return f"""<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>QAI Repo Decision Matrix</title>
<style>
body{{font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Roboto,Helvetica,Arial,sans-serif;background:#0b1020;color:#e6edf3;max-width:1500px;margin:0 auto;padding:24px;line-height:1.55}}
pre{{white-space:pre-wrap;word-break:break-word;background:#111827;padding:18px;border-radius:12px;border:1px solid #334155}}
</style>
</head>
<body>
<pre>{html.escape(md_text)}</pre>
</body>
</html>"""


def write_csv(path: Path, rows, fieldnames):
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({k: row.get(k, "") for k in fieldnames})


def main():
    ap = argparse.ArgumentParser(description="Deep repo assessment çıktısından operasyonel karar matrisi üretir.")
    ap.add_argument("--root", required=True, help="Repo kök dizini")
    ap.add_argument("--full-scan-dir", required=True, help="İlk tarama rapor klasörü")
    ap.add_argument("--deep-dir", required=True, help="Derin assessment klasörü")
    ap.add_argument("--out", required=True, help="Karar matrisi çıktı klasörü")
    args = ap.parse_args()

    root = Path(args.root).expanduser().resolve()
    full_scan_dir = Path(args.full_scan_dir).expanduser().resolve()
    deep_dir = Path(args.deep_dir).expanduser().resolve()
    out = Path(args.out).expanduser().resolve()
    out.mkdir(parents=True, exist_ok=True)

    repo_inventory = full_scan_dir / "repo_inventory.csv"
    directory_inventory = full_scan_dir / "directory_inventory.csv"
    repo_summary = full_scan_dir / "repo_summary.json"
    deep_json = deep_dir / "deep_repo_assessment.json"
    deep_md = deep_dir / "deep_repo_assessment.md"
    deep_html = deep_dir / "deep_repo_assessment.html"

    required = [repo_inventory, directory_inventory, repo_summary, deep_json, deep_md, deep_html]
    missing = [str(p) for p in required if not p.exists()]
    if missing:
        print("EKSIK_GIRDI_DOSYALARI:")
        for item in missing:
            print(item)
        sys.exit(2)

    repo_inventory_rows = read_csv(repo_inventory)
    dir_inventory_rows = read_csv(directory_inventory)
    _repo_summary_data = read_json(repo_summary)
    deep_json_data = read_json(deep_json)

    state = collect_repo_state(root, repo_inventory_rows, dir_inventory_rows, deep_json_data)
    service_decisions = build_service_decisions(state)
    backup_plan = build_backup_archive_plan(state)
    ops_matrix = build_ops_matrix(state)
    audit_plan = build_dependency_audit_plan(state)
    exclusion_plan = build_exclusion_plan(state)
    runbook_actions = build_runbook_actions(state, service_decisions, ops_matrix, exclusion_plan, backup_plan, audit_plan)
    shell_commands = build_shell_commands(state, service_decisions, backup_plan, exclusion_plan, audit_plan)

    md_text = render_markdown(state, service_decisions, backup_plan, ops_matrix, audit_plan, exclusion_plan, runbook_actions, shell_commands)
    html_text = render_html(md_text)

    out_md = out / "repo_decision_matrix.md"
    out_html = out / "repo_decision_matrix.html"
    out_json = out / "repo_decision_matrix.json"
    out_services_csv = out / "canonical_service_decisions.csv"
    out_ops_csv = out / "ops_risk_matrix.csv"
    out_backup_csv = out / "backup_archive_plan.csv"
    out_actions_csv = out / "runbook_actions.csv"

    out_md.write_text(md_text, encoding="utf-8")
    out_html.write_text(html_text, encoding="utf-8")

    with out_json.open("w", encoding="utf-8") as f:
        json.dump({
            "state_summary": {
                "root": state["root"],
                "inventory_count": state["inventory_count"],
                "directory_count": state["directory_count"],
                "generated_at": datetime.now().isoformat(timespec="seconds"),
            },
            "service_decisions": service_decisions,
            "backup_archive_plan": backup_plan,
            "ops_risk_matrix": ops_matrix,
            "dependency_audit_plan": audit_plan,
            "exclusion_plan": exclusion_plan,
            "runbook_actions": runbook_actions,
            "shell_commands": shell_commands,
            "duplicate_names": state["duplicate_names"][:120],
        }, f, ensure_ascii=False, indent=2)

    write_csv(
        out_services_csv,
        [
            {
                "service_key": x["service_key"],
                "chosen_canonical": x["chosen_canonical"],
                "alternates": ", ".join(x["alternates"]),
                "duplicate_roots": ", ".join(x["duplicate_roots"]),
                "evidence_count": x["evidence_count"],
            }
            for x in service_decisions
        ],
        ["service_key", "chosen_canonical", "alternates", "duplicate_roots", "evidence_count"]
    )

    ops_rows = []
    for bucket, items in ops_matrix.items():
        for item in items:
            ops_rows.append({
                "bucket": bucket,
                "relative_path": item["relative_path"],
                "role": item["role"],
                "summary": item["summary"],
            })
    write_csv(out_ops_csv, ops_rows, ["bucket", "relative_path", "role", "summary"])
    write_csv(out_backup_csv, backup_plan, ["src", "dst"])
    write_csv(out_actions_csv, runbook_actions, ["phase", "priority", "title", "detail"])

    print(f"DECISION_MD:{out_md}")
    print(f"DECISION_HTML:{out_html}")
    print(f"DECISION_JSON:{out_json}")
    print(f"SERVICES_CSV:{out_services_csv}")
    print(f"OPS_CSV:{out_ops_csv}")
    print(f"BACKUP_CSV:{out_backup_csv}")
    print(f"ACTIONS_CSV:{out_actions_csv}")
    print(f"CANONICAL_SERVICES:{len(service_decisions)}")
    print(f"BACKUP_ITEMS:{len(backup_plan)}")
    print(f"OPS_SAFE:{len(ops_matrix['safe'])}")
    print(f"OPS_RECOVERY:{len(ops_matrix['recovery'])}")
    print(f"OPS_DESTRUCTIVE:{len(ops_matrix['destructive'])}")
    print(f"OPS_REVIEW:{len(ops_matrix['review'])}")
    print("STATUS:OK")


if __name__ == "__main__":
    main()
