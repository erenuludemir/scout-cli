#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
IOS_ROOT="$REPO/ios/QuantumAIMobile"
APP_ROOT="$IOS_ROOT/QuantumAIMobile"
OPS_ROOT="$REPO/ops"
LOG_DIR="$REPO/_logs/final_polish"
BACKUP_DIR="$REPO/_backups/final_polish"
COMPOSE_FILE="$REPO/compose.yml"
TS="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$OPS_ROOT" "$LOG_DIR" "$BACKUP_DIR" "$BACKUP_DIR/ios_duplicates" "$BACKUP_DIR/compose"

python3 - "$COMPOSE_FILE" "$IOS_ROOT/Package.swift" "$APP_ROOT" "$BACKUP_DIR/ios_duplicates" "$TS" <<'PY'
from pathlib import Path
import sys,re,shutil

compose_path=Path(sys.argv[1])
package_path=Path(sys.argv[2])
app_root=Path(sys.argv[3])
dup_backup=Path(sys.argv[4])
ts=sys.argv[5]

compose=compose_path.read_text(encoding="utf-8")
package=package_path.read_text(encoding="utf-8")

required_volumes=[
    "demo_app_redpanda_data",
    "dex_logs",
    "gateway_file_logs",
    "gli_logs",
    "gli_mainnet_logs",
    "gli_sepolia_logs",
    "qai_redpanda",
    "quantumai_usdt_logs",
    "quantumai_usdt_v2_logs",
]

def patch_volumes(text:str)->str:
    block="volumes:\n" + "".join(f"  {v}:\n" for v in required_volumes)
    m=re.search(r'(?ms)^volumes:\n(.*?)(?=^[A-Za-z0-9_.-]+:\n|\Z)',text)
    if m:
        existing_block=text[m.start():m.end()]
        existing_names=set(re.findall(r'(?m)^  ([A-Za-z0-9_.-]+):\s*$',existing_block))
        merged=sorted(existing_names.union(required_volumes))
        block="volumes:\n" + "".join(f"  {v}:\n" for v in merged)
        return text[:m.start()] + block + ("\n" if not block.endswith("\n") else "") + text[m.end():]
    n=re.search(r'(?m)^networks:\n',text)
    if n:
        return text[:n.start()] + block + "\n" + text[n.start():]
    return text.rstrip("\n") + "\n\n" + block + "\n"

compose_new=patch_volumes(compose)
if compose_new != compose:
    compose_path.write_text(compose_new,encoding="utf-8")

if 'exclude: ["Runbook"]' not in package:
    package_new=re.sub(
        r'(\.target\(\s*name:\s*"QuantumAIMobile",\s*path:\s*"QuantumAIMobile",)',
        r'\1\n            exclude: ["Runbook"],',
        package,
        count=1,
        flags=re.S
    )
    if package_new == package:
        package_new=re.sub(
            r'(\.target\(\s*name:\s*"QuantumAIMobile",)',
            r'\1\n            exclude: ["Runbook"],',
            package,
            count=1,
            flags=re.S
        )
    package=package_new
    package_path.write_text(package,encoding="utf-8")

all_sync=list(app_root.rglob("SyncClient.swift"))
keepers=[]
for p in all_sync:
    if p.as_posix().endswith("/SettingsKit/SyncClient.swift"):
        keepers.append(p)

keeper=keepers[0] if keepers else None
moved=[]
for p in all_sync:
    if keeper and p.resolve()==keeper.resolve():
        continue
    rel=p.relative_to(app_root)
    target=dup_backup / f"{rel.as_posix().replace('/','__')}.{ts}.disabled"
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.move(str(p),str(target))
    moved.append((str(p),str(target)))

other_dups={}
for p in app_root.rglob("*.swift"):
    if ".build" in p.parts or ".swiftpm" in p.parts:
        continue
    other_dups.setdefault(p.name,[]).append(p)
dup_report=[]
for name,items in sorted(other_dups.items()):
    if len(items)>1:
        dup_report.append((name,[str(x) for x in items]))

report=Path(sys.argv[4]).parent / f"repair_report_{ts}.txt"
with report.open("w",encoding="utf-8") as f:
    f.write(f"COMPOSE_PATCHED={'YES' if compose_new != compose else 'NO'}\n")
    f.write("REQUIRED_VOLUMES=" + ",".join(required_volumes) + "\n")
    f.write(f"PACKAGE_RUNBOOK_EXCLUDED={'YES' if 'exclude: [\"Runbook\"]' in package else 'NO'}\n")
    f.write(f"SYNCCLIENT_KEEPER={keeper if keeper else 'MISSING'}\n")
    if moved:
        for src,dst in moved:
            f.write(f"MOVED_DUPLICATE={src} -> {dst}\n")
    else:
        f.write("MOVED_DUPLICATE=NONE\n")
    if dup_report:
        for name,items in dup_report:
            f.write(f"DUPLICATE_BASENAME={name}\n")
            for item in items:
                f.write(f"  {item}\n")
    else:
        f.write("DUPLICATE_BASENAME=NONE\n")
print(report)
PY

cat > "$OPS_ROOT/qai_ios_megapipeline_validate.sh" <<'BASH2'
#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
IOS_ROOT="$REPO/ios/QuantumAIMobile"
LOG_DIR="$REPO/_logs/ios_megapipeline"
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_DIR"

PACKAGE_DUMP="$LOG_DIR/${TS}_package_dump.json"
SWIFT_BUILD_LOG="$LOG_DIR/${TS}_swift_build.log"
SWIFT_TEST_LOG="$LOG_DIR/${TS}_swift_test.log"
REPORT_LOG="$LOG_DIR/${TS}_validate_report.log"

XCODE_APP="/Applications/Xcode.app/Contents/Developer"
if [ -d "$XCODE_APP" ]; then
  export DEVELOPER_DIR="$XCODE_APP"
fi

pushd "$IOS_ROOT" >/dev/null
swift package dump-package > "$PACKAGE_DUMP"

if swift build > "$SWIFT_BUILD_LOG" 2>&1; then
  BUILD_STATUS="OK"
else
  BUILD_STATUS="FAIL"
fi

if swift test > "$SWIFT_TEST_LOG" 2>&1; then
  TEST_STATUS="OK"
else
  TEST_STATUS="FAIL"
fi
popd >/dev/null

{
  echo "IOS_ROOT=$IOS_ROOT"
  echo "DEVELOPER_DIR=${DEVELOPER_DIR:-UNSET}"
  echo "PACKAGE_DUMP=$PACKAGE_DUMP"
  echo "SWIFT_BUILD_LOG=$SWIFT_BUILD_LOG"
  echo "SWIFT_TEST_LOG=$SWIFT_TEST_LOG"
  echo "BUILD_STATUS=$BUILD_STATUS"
  echo "TEST_STATUS=$TEST_STATUS"
} | tee "$REPORT_LOG"

[ "$BUILD_STATUS" = "OK" ] && [ "$TEST_STATUS" = "OK" ]
BASH2
chmod +x "$OPS_ROOT/qai_ios_megapipeline_validate.sh"

cat > "$OPS_ROOT/qai_compose_precheck.sh" <<'BASH3'
#!/usr/bin/env bash
set -euo pipefail

REPO="/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3"
COMPOSE_FILE="$REPO/compose.yml"
LOG_DIR="$REPO/_logs/compose_repair"
TS="$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_DIR"

OUT="$LOG_DIR/${TS}_compose_precheck.log"
docker compose -f "$COMPOSE_FILE" -p quantumai-stack config > "$OUT" 2>&1

{
  echo "COMPOSE_PRECHECK=OK"
  echo "LOG=$OUT"
} | tee "$LOG_DIR/${TS}_compose_precheck_report.log"
BASH3
chmod +x "$OPS_ROOT/qai_compose_precheck.sh"

REPAIR_REPORT="$(python3 - <<'PY'
from pathlib import Path
import glob
files=sorted(glob.glob("/Users/erenuludemir/QuantumAI-Dockerized-System.migrated.20250908_121149.migrated.20250908_121221 3/_backups/final_polish/repair_report_*.txt"))
print(files[-1] if files else "")
PY
)"

"$OPS_ROOT/qai_compose_precheck.sh" > "$LOG_DIR/${TS}_compose_stdout.log" 2>&1 || true
"$OPS_ROOT/qai_ios_megapipeline_validate.sh" > "$LOG_DIR/${TS}_ios_validate_stdout.log" 2>&1 || true

LATEST_COMPOSE_PRECHECK="$(ls -1t "$REPO/_logs/compose_repair"/*_compose_precheck_report.log 2>/dev/null | head -n1 || true)"
LATEST_IOS_VALIDATE="$(ls -1t "$REPO/_logs/ios_megapipeline"/*_validate_report.log 2>/dev/null | head -n1 || true)"

{
  echo "REPAIR_REPORT=$REPAIR_REPORT"
  [ -n "$LATEST_COMPOSE_PRECHECK" ] && echo "COMPOSE_PRECHECK_REPORT=$LATEST_COMPOSE_PRECHECK"
  [ -n "$LATEST_IOS_VALIDATE" ] && echo "IOS_VALIDATE_REPORT=$LATEST_IOS_VALIDATE"
  echo "SYNCCLIENT_PATHS_AFTER_PATCH:"
  find "$APP_ROOT" -type f -name 'SyncClient.swift' | sort
  echo "RUNBOOK_EXCLUDE_CHECK:"
  grep -n 'exclude: \["Runbook"\]' "$IOS_ROOT/Package.swift" || true
  echo "ROOT_VOLUMES_CHECK:"
  awk 'BEGIN{p=0} /^volumes:/{p=1} p{print} /^[A-Za-z0-9_.-]+:$/ && $0!="volumes:" && p{exit}' "$COMPOSE_FILE" | sed '$d'
  echo "COMPOSE_ERROR_FILTER:"
  if [ -n "$LATEST_COMPOSE_PRECHECK" ]; then
    PRECHECK_LOG="$(sed -n 's/^LOG=//p' "$LATEST_COMPOSE_PRECHECK" | tail -n1)"
    [ -n "$PRECHECK_LOG" ] && egrep -i 'undefined volume|invalid compose project|error' "$PRECHECK_LOG" || true
  fi
  echo "IOS_TEST_ERROR_FILTER:"
  if [ -n "$LATEST_IOS_VALIDATE" ]; then
    TEST_LOG="$(sed -n 's/^SWIFT_TEST_LOG=//p' "$LATEST_IOS_VALIDATE" | tail -n1)"
    [ -n "$TEST_LOG" ] && egrep -i 'no such module|multiple producers|error:|fatalError' "$TEST_LOG" || true
  fi
} | tee "$LOG_DIR/${TS}_final_summary.log"
