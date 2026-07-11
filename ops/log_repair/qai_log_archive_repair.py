#!/usr/bin/env python3
from __future__ import annotations
import argparse
import collections
import json
import re
import shutil
import zipfile
from pathlib import Path

ROOT_HINT = "/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
TOP10_ORDER = [
    "rootview_fix_build_20260330_132612.log",
    "20260321_003039_ios_diag.log",
    "20260321_002329.swift_test.log",
    "20260321_003329.swift_build.log",
    "20260321_003057.final_report.log",
    "20260320_201847.final_report.log",
    "20260321_021058.swift_build.log",
    "20260321_021146.final_report.log",
    "critical_matches 2.log",
    "showdestinations.log",
]

CLASSIFIERS = {
    "Batch A": [
        ".swift_build.log",
        ".swift_test.log",
        "_ios_diag.log",
    ],
    "Batch B": [
        ".final_report.log",
        "critical_matches",
        "rootview_fix_build",
    ],
    "Batch C": [
        ".devices.",
        "showdestinations.log",
    ],
}

ERROR_PATTERNS = [
    re.compile(r"\berror:.*", re.IGNORECASE),
    re.compile(r"\bfatalError\b.*", re.IGNORECASE),
    re.compile(r"\bwarning:.*", re.IGNORECASE),
    re.compile(r"\btcp_input\b.*", re.IGNORECASE),
    re.compile(r"\bnw_read_request_report\b.*", re.IGNORECASE),
    re.compile(r"multiple producers", re.IGNORECASE),
    re.compile(r"invalid redeclaration", re.IGNORECASE),
    re.compile(r"ambiguous for type lookup", re.IGNORECASE),
    re.compile(r"only available in macOS", re.IGNORECASE),
    re.compile(r"cannot find 'UIDevice' in scope", re.IGNORECASE),
    re.compile(r"has no member 'watchlist'", re.IGNORECASE),
]

def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""

def classify(name: str) -> str:
    for batch, tokens in CLASSIFIERS.items():
        if any(token in name for token in tokens):
            return batch
    return "Batch D"

def collect_matches(text: str) -> list[str]:
    results: list[str] = []
    seen: set[str] = set()
    for line in text.splitlines():
        line = line.rstrip()
        for pattern in ERROR_PATTERNS:
            if pattern.search(line):
                if line not in seen:
                    results.append(line)
                    seen.add(line)
                break
        if len(results) >= 80:
            break
    return results

def build_top10(root: Path) -> list[dict]:
    entries = []
    for relative_name in TOP10_ORDER:
        target = root / "log" / relative_name
        if not target.exists():
            continue
        text = read_text(target)
        lines = collect_matches(text)
        entries.append({
            "file": str(target),
            "reason": explain_file(relative_name, text),
            "read_order": len(entries) + 1,
            "high_signal_lines": lines[:12],
        })
    return entries

def explain_file(name: str, text: str) -> str:
    lowered = text.lower()
    if "rootview_fix_build" in name:
        return "Host projesinin package çözümlenmiş son büyük derleme izi; final referans build."
    if "ios_diag" in name:
        return "Unhandled file uyarıları ve SyncClient.swift.o multiple producers kök arızası."
    if "20260321_002329.swift_test.log" in name:
        return "RemoteMonitor.swift içinde UIDevice kapsamı ve AppEnvironment.watchlist uyumsuzluğu."
    if "20260321_003329.swift_build.log" in name:
        return "WalletKit tarafında RawTransaction/signTRON redeclaration ve ambiguity hataları."
    if "20260321_003057.final_report.log" in name:
        return "WalletKit derleme kırılımlarının özet raporu."
    if "20260320_201847.final_report.log" in name:
        return "CryptoKit/ObservableObject/Published deployment target uyumsuzluk özeti."
    if "20260321_021058.swift_build.log" in name:
        return "Başarılı derleme baseline; temiz durumla kırık durum arasındaki fark için okunmalı."
    if "20260321_021146.final_report.log" in name:
        return "BUILD_RC=0 TEST_RC=0 çevre ve toolchain doğrulaması; known-good environment."
    if "critical_matches" in name:
        return "Infra tarafında Redpanda admin auth ve postgres_exporter.yml eksikliği gibi kritik uyarılar."
    if "showdestinations" in name:
        return "Xcode hedef cihaz/simulator matrisi; hatalı destination seçimlerini temizlemek için referans."
    if "multiple producers" in lowered:
        return "Multiple producers çatışması."
    if "invalid redeclaration" in lowered:
        return "Yinelenmiş sembol tanımları."
    return "Yüksek sinyal içeren kök neden adayı."

def write_markdown(path: Path, title: str, body: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("# " + title + "\n\n" + "\n".join(body).rstrip() + "\n", encoding="utf-8")

def summarize_batch(batch_name: str, files: list[Path]) -> list[str]:
    body = []
    body.append(f"- Toplam dosya: {len(files)}")
    body.append("")
    for file in sorted(files, key=lambda p: p.name)[:200]:
        text = read_text(file)
        matches = collect_matches(text)
        body.append(f"## {file.name}")
        body.append(f"- Yol: `{file}`")
        body.append(f"- Match sayısı: {len(matches)}")
        for line in matches[:12]:
            body.append(f"- {line}")
        body.append("")
    return body

def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--zip", required=True, help="log.zip yolu")
    parser.add_argument("--out", required=True, help="çıktı dizini")
    args = parser.parse_args()

    zip_path = Path(args.zip).expanduser().resolve()
    out_root = Path(args.out).expanduser().resolve()
    extract_root = out_root / "extracted"
    reports_root = out_root / "reports"

    if out_root.exists():
        shutil.rmtree(out_root)
    extract_root.mkdir(parents=True, exist_ok=True)
    reports_root.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(extract_root)

    files = [p for p in extract_root.rglob("*") if p.is_file()]
    real_files = [p for p in files if "__MACOSX" not in p.parts]
    counts = collections.Counter()
    batches: dict[str, list[Path]] = collections.defaultdict(list)

    for file in real_files:
        counts[file.suffix.lower() or "<noext>"] += 1
        batches[classify(file.name)].append(file)

    manifest = {
        "zip": str(zip_path),
        "out_root": str(out_root),
        "root_hint": ROOT_HINT,
        "total_files": len(real_files),
        "suffix_counts": dict(counts),
        "batches": {name: len(paths) for name, paths in batches.items()},
    }
    (reports_root / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

    for batch_name in ("Batch A", "Batch B", "Batch C", "Batch D"):
        body = summarize_batch(batch_name, batches.get(batch_name, []))
        write_markdown(reports_root / f"{batch_name.lower().replace(' ', '_')}.md", batch_name, body)

    top10 = build_top10(extract_root)
    top10_lines = []
    for item in top10:
        top10_lines.append(f"## {item['read_order']}. {Path(item['file']).name}")
        top10_lines.append(f"- Yol: `{item['file']}`")
        top10_lines.append(f"- Neden: {item['reason']}")
        for line in item["high_signal_lines"]:
            top10_lines.append(f"- {line}")
        top10_lines.append("")
    write_markdown(reports_root / "top10_read_order.md", "Top 10 Read Order", top10_lines)

    noise_lines = []
    transient_count = 0
    for file in real_files:
        text = read_text(file)
        for line in text.splitlines():
            if "tcp_input" in line or "nw_read_request_report" in line:
                transient_count += 1
                if len(noise_lines) < 120:
                    noise_lines.append(f"- {line}")
    write_markdown(
        reports_root / "network_noise.md",
        "Network Noise",
        [
            f"- Toplam transient ağ satırı: {transient_count}",
            "- `tcp_input ... flags=[R|R.] state=LAST_ACK` satırları uygulama kaynaklı kesin crash kanıtı değil, kapanan bağlantı gürültüsüdür.",
            "- `nw_read_request_report ... Operation timed out` satırları retry/backoff ile ele alınmalıdır.",
            "",
            "## Örnek satırlar",
            *noise_lines
        ]
    )

    print(str(reports_root / "manifest.json"))
    print(str(reports_root / "batch_a.md"))
    print(str(reports_root / "batch_b.md"))
    print(str(reports_root / "batch_c.md"))
    print(str(reports_root / "batch_d.md"))
    print(str(reports_root / "top10_read_order.md"))
    print(str(reports_root / "network_noise.md"))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
