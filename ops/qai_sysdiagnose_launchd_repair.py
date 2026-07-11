#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import plistlib
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
REPORT_ROOT = REPO_ROOT / "_reports" / "sysdiagnose_launchd_repair"
LOG_ROOT = REPO_ROOT / "_logs" / "sysdiagnose_launchd_repair"

HOME = Path.home()
USER = HOME.name
UID = str(HOME.stat().st_uid)
LAUNCH_AGENTS_DIR = HOME / "Library" / "LaunchAgents"
DISABLED_DIR = HOME / "Library" / "LaunchAgents.disabled"

PATCH_LABELS = {
    "com.qai.sshagent",
    "com.qai.system.rotate",
}

DISABLE_REASONS = {
    "com.erenuludemir.quantumai.gunicorn": "obsolete-repo-path",
    "com.qai.autoheal.restart": "missing-megapipeline-script",
    "com.qai.autoheal.v2": "missing-megapipeline-script",
    "com.qai.compose-duty": "broken-plist",
    "com.qai.compose-logs": "broken-plist",
    "com.qai.cyberdeck": "missing-cyberdeck-root",
    "com.qai.cyberdeck.watchdog": "missing-cyberdeck-root",
    "com.qai.desktop.cleaner": "missing-log-root-and-destructive-cleaner",
    "com.qai.desktopwatcher": "external-volume-desktop-mover-disabled",
    "com.qai.devcontainer.forward": "missing-legacy-workspace",
    "com.qai.doctor.v2": "missing-megapipeline-script",
    "com.qai.doctorqai.watchdog": "missing-megapipeline-script",
    "com.qai.electron": "missing-megapipeline-root",
    "com.qai.godmode": "missing-megapipeline-root",
    "com.qai.guardian": "legacy-guardian-disabled-to-stop-respawn-noise",
    "com.qai.lacie.doctor": "missing-lacie-doctor-script",
    "com.qai.lacie.healthcheck": "missing-lacie-healthcheck-script",
    "com.qai.logclean": "missing-cyberdeck-root",
    "com.qai.megapipeline": "missing-megapipeline-root",
    "com.qai.monitor": "missing-diagnostics-root",
    "com.qai.montecarlo.autostart": "broken-plist-and-missing-montecarlo-root",
    "com.qai.safe.rollback": "missing-megapipeline-root",
    "com.qai.system.livewatch": "redundant-livewatch-replaced-by-supervisord",
    "com.qai.trainer": "missing-megapipeline-root",
    "com.qai.trainingdashboard": "missing-megapipeline-root",
    "com.quantumai.completionboot": "missing-legacy-lacie1-root",
    "com.quantumai.drive_doctor": "missing-drive-doctor-script",
    "com.quantumai.master-orchestrator": "broken-plist",
}

LEGACY_TOKENS = (
    "/Volumes/LaCie/QAI_MegaPipeline",
    "/Volumes/LaCie/QAI_CyberDeck",
    "/Volumes/LaCie 1/QAI_MegaPipeline",
    "/Users/erenuludemir/QuantumAI-Dockerized-System",
    "/Volumes/LaCie/_qai",
    "/Volumes/LaCie/QuantumAI-Diagnostics",
)

KNOWN_STALE_LOGS = {
    "com.qai.autoheal.v2": [
        HOME / "Library" / "Logs" / "qai_autoheal_v2.stderr.log",
        HOME / "Library" / "Logs" / "qai_autoheal_v2.stdout.log",
    ],
    "com.qai.devcontainer.forward": [
        HOME / "Library" / "Logs" / "com.qai.devcontainer.forward.err.log",
        HOME / "Library" / "Logs" / "com.qai.devcontainer.forward.out.log",
    ],
    "com.qai.doctor.v2": [
        HOME / "Library" / "Logs" / "qai_doctor_v2.stderr.log",
        HOME / "Library" / "Logs" / "qai_doctor_v2.stdout.log",
    ],
    "com.qai.montecarlo.autostart": [
        Path("/Users/Shared/com.qai.montecarlo.err.log"),
        Path("/Users/Shared/com.qai.montecarlo.out.log"),
    ],
}


def utc_now() -> str:
    return (
        datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def stamp_now() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def expand_vars(value: str, home: Path = HOME, user: str = USER) -> str:
    return (
        value.replace("${HOME}", str(home))
        .replace("$HOME", str(home))
        .replace("$USER", user)
    )


def snapshot_paths(data: dict[str, Any]) -> list[str]:
    items: list[str] = []
    for key in ("WorkingDirectory", "StandardOutPath", "StandardErrorPath"):
        value = data.get(key)
        if isinstance(value, str):
            items.append(value)
    for arg in data.get("ProgramArguments", []):
        if isinstance(arg, str):
            items.append(arg)
    return items


def rebuild_sshagent(home: Path = HOME) -> dict[str, Any]:
    command = (
        f'export SSH_AUTH_SOCK="{home}/.ssh/ssh_auth_sock"; '
        f'(/usr/bin/ssh-agent -a "$SSH_AUTH_SOCK" >/dev/null 2>&1 || true); '
        'for k in "$HOME/.ssh/id_rsa" "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ecdsa"; '
        'do [[ -f "$k" ]] && /usr/bin/ssh-add "$k" >/dev/null 2>&1 || true; done; '
        "exit 0"
    )
    return {
        "Label": "com.qai.sshagent",
        "ProgramArguments": ["/bin/zsh", "-lc", command],
        "RunAtLoad": True,
        "KeepAlive": False,
        "StandardOutPath": str(home / "Library" / "Logs" / "com.qai.sshagent.out.log"),
        "StandardErrorPath": str(home / "Library" / "Logs" / "com.qai.sshagent.err.log"),
    }


def patch_system_rotate(data: dict[str, Any], home: Path = HOME) -> dict[str, Any]:
    patched = dict(data)
    for key in ("StandardOutPath", "StandardErrorPath"):
        value = patched.get(key)
        if isinstance(value, str):
            patched[key] = expand_vars(value, home=home)
    args = list(patched.get("ProgramArguments", []))
    if len(args) >= 3 and isinstance(args[2], str):
        args[2] = expand_vars(args[2], home=home)
    patched["ProgramArguments"] = args
    return patched


def lint_plist(path: Path) -> tuple[bool, str]:
    proc = subprocess.run(
        ["plutil", "-lint", str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    output = (proc.stdout or proc.stderr or "").strip()
    return proc.returncode == 0, output


def launchctl(*args: str) -> tuple[int, str]:
    proc = subprocess.run(
        ["launchctl", *args],
        capture_output=True,
        text=True,
        check=False,
    )
    output = "\n".join(part.strip() for part in (proc.stdout, proc.stderr) if part.strip())
    return proc.returncode, output


def bootout_label(label: str, path: Path | None = None) -> list[dict[str, Any]]:
    attempts: list[list[str]] = [
        ["bootout", f"gui/{UID}/{label}"],
    ]
    if path is not None:
        attempts.append(["bootout", f"gui/{UID}", str(path)])
    results = []
    for args in attempts:
        code, output = launchctl(*args)
        results.append({"args": args, "code": code, "output": output})
    return results


def disable_label(label: str) -> dict[str, Any]:
    code, output = launchctl("disable", f"gui/{UID}/{label}")
    return {"args": ["disable", f"gui/{UID}/{label}"], "code": code, "output": output}


def enable_label(label: str) -> dict[str, Any]:
    code, output = launchctl("enable", f"gui/{UID}/{label}")
    return {"args": ["enable", f"gui/{UID}/{label}"], "code": code, "output": output}


def bootstrap_label(label: str, path: Path) -> list[dict[str, Any]]:
    actions = [enable_label(label)]
    code, output = launchctl("bootstrap", f"gui/{UID}", str(path))
    actions.append(
        {
            "args": ["bootstrap", f"gui/{UID}", str(path)],
            "code": code,
            "output": output,
        }
    )
    return actions


def kickstart_label(label: str) -> dict[str, Any]:
    code, output = launchctl("kickstart", "-k", f"gui/{UID}/{label}")
    return {"args": ["kickstart", "-k", f"gui/{UID}/{label}"], "code": code, "output": output}


def status_snippet(label: str) -> str:
    proc = subprocess.run(
        ["launchctl", "print", f"gui/{UID}/{label}"],
        capture_output=True,
        text=True,
        check=False,
    )
    text = "\n".join(part.strip() for part in (proc.stdout, proc.stderr) if part.strip())
    lines = text.splitlines()
    return "\n".join(lines[:16])


@dataclass
class ActionResult:
    label: str
    plist_name: str
    action: str
    reason: str
    status: str
    before_paths: list[str]
    after_paths: list[str]
    backup_path: str
    target_path: str
    commands: list[dict[str, Any]]
    lint: str = ""
    note: str = ""

    def to_dict(self) -> dict[str, Any]:
        return {
            "label": self.label,
            "plist_name": self.plist_name,
            "action": self.action,
            "reason": self.reason,
            "status": self.status,
            "before_paths": self.before_paths,
            "after_paths": self.after_paths,
            "backup_path": self.backup_path,
            "target_path": self.target_path,
            "commands": self.commands,
            "lint": self.lint,
            "note": self.note,
        }


def ensure_parent_dirs(data: dict[str, Any]) -> None:
    for key in ("StandardOutPath", "StandardErrorPath"):
        value = data.get(key)
        if isinstance(value, str):
            Path(value).expanduser().parent.mkdir(parents=True, exist_ok=True)


def detect_label(path: Path, data: dict[str, Any] | None = None) -> str:
    if data and isinstance(data.get("Label"), str):
        return str(data["Label"])
    return path.name.replace(".plist", "")


def classify(label: str, data: dict[str, Any] | None, parse_error: str | None) -> tuple[str, str]:
    if label in PATCH_LABELS:
        if label == "com.qai.sshagent":
            return "rebuild", "broken-sshagent-plist-and-keepalive-loop"
        return "patch", "expand-launchd-home-paths"
    if label in DISABLE_REASONS:
        return "disable", DISABLE_REASONS[label]
    if parse_error:
        return "disable", "broken-plist"
    if data:
        joined = "\n".join(snapshot_paths(data))
        if any(token in joined for token in LEGACY_TOKENS):
            return "disable", "legacy-path-reference"
        if "$HOME" in joined or "${HOME}" in joined or "$USER" in joined:
            return "disable", "unexpanded-launchd-vars"
    return "skip", "not-targeted"


def backup_original(path: Path, backup_dir: Path) -> Path:
    backup_dir.mkdir(parents=True, exist_ok=True)
    target = backup_dir / path.name
    shutil.copy2(path, target)
    return target


def quarantine_path(path: Path, quarantine_dir: Path) -> Path:
    quarantine_dir.mkdir(parents=True, exist_ok=True)
    target = quarantine_dir / path.name
    if target.exists():
        target = quarantine_dir / f"{path.stem}.{stamp_now()}.plist"
    shutil.move(str(path), str(target))
    return target


def write_plist(path: Path, data: dict[str, Any]) -> None:
    with path.open("wb") as handle:
        plistlib.dump(data, handle, sort_keys=True)


def repair_launchagent(path: Path, backup_dir: Path, quarantine_dir: Path) -> ActionResult:
    parse_error: str | None = None
    data: dict[str, Any] | None = None
    before_paths: list[str] = []
    try:
        with path.open("rb") as handle:
            data = plistlib.load(handle)
        before_paths = snapshot_paths(data)
    except Exception as exc:
        parse_error = str(exc)
    label = detect_label(path, data)
    action, reason = classify(label, data, parse_error)
    backup_path = backup_original(path, backup_dir)
    commands: list[dict[str, Any]] = []
    after_paths: list[str] = []
    lint_output = ""
    note = parse_error or ""

    if action == "disable":
        commands.extend(bootout_label(label, path))
        commands.append(disable_label(label))
        target = quarantine_path(path, quarantine_dir)
        return ActionResult(
            label=label,
            plist_name=path.name,
            action=action,
            reason=reason,
            status="disabled",
            before_paths=before_paths,
            after_paths=[],
            backup_path=str(backup_path),
            target_path=str(target),
            commands=commands,
            note=note,
        )

    if action == "patch":
        assert data is not None
        patched = patch_system_rotate(data)
        ensure_parent_dirs(patched)
        commands.extend(bootout_label(label, path))
        write_plist(path, patched)
        ok, lint_output = lint_plist(path)
        after_paths = snapshot_paths(patched)
        commands.extend(bootstrap_label(label, path))
        status = "patched" if ok else "lint-failed"
        return ActionResult(
            label=label,
            plist_name=path.name,
            action=action,
            reason=reason,
            status=status,
            before_paths=before_paths,
            after_paths=after_paths,
            backup_path=str(backup_path),
            target_path=str(path),
            commands=commands,
            lint=lint_output,
        )

    if action == "rebuild":
        rebuilt = rebuild_sshagent()
        ensure_parent_dirs(rebuilt)
        commands.extend(bootout_label(label, path))
        write_plist(path, rebuilt)
        ok, lint_output = lint_plist(path)
        after_paths = snapshot_paths(rebuilt)
        commands.extend(bootstrap_label(label, path))
        commands.append(kickstart_label(label))
        status = "rebuilt" if ok else "lint-failed"
        return ActionResult(
            label=label,
            plist_name=path.name,
            action=action,
            reason=reason,
            status=status,
            before_paths=before_paths,
            after_paths=after_paths,
            backup_path=str(backup_path),
            target_path=str(path),
            commands=commands,
            lint=lint_output,
            note=note,
        )

    return ActionResult(
        label=label,
        plist_name=path.name,
        action=action,
        reason=reason,
        status="skipped",
        before_paths=before_paths,
        after_paths=[],
        backup_path=str(backup_path),
        target_path=str(path),
        commands=[],
        note=note,
    )


def write_report(
    report_dir: Path,
    sysdiagnose_path: str,
    actions: list[ActionResult],
    cleaned_logs: list[dict[str, Any]],
) -> dict[str, str]:
    report_dir.mkdir(parents=True, exist_ok=True)
    json_path = report_dir / "summary.json"
    md_path = report_dir / "summary.md"

    payload = {
        "timestamp": utc_now(),
        "sysdiagnose_path": sysdiagnose_path,
        "disabled_count": sum(1 for action in actions if action.status == "disabled"),
        "patched_count": sum(
            1 for action in actions if action.status in {"patched", "rebuilt"}
        ),
        "skipped_count": sum(1 for action in actions if action.status == "skipped"),
        "actions": [action.to_dict() for action in actions],
        "cleaned_logs": cleaned_logs,
    }
    json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Sysdiagnose Launchd Repair",
        "",
        f"- timestamp: {payload['timestamp']}",
        f"- sysdiagnose_path: {sysdiagnose_path}",
        f"- disabled_count: {payload['disabled_count']}",
        f"- patched_count: {payload['patched_count']}",
        f"- skipped_count: {payload['skipped_count']}",
        f"- cleaned_logs: {len(cleaned_logs)}",
        "",
        "| label | action | status | reason |",
        "|---|---|---|---|",
    ]
    for action in actions:
        lines.append(
            f"| {action.label} | {action.action} | {action.status} | {action.reason} |"
        )
    lines.extend(
        [
            "",
            "## Cleaned Logs",
            "",
        ]
    )
    if cleaned_logs:
        lines.extend(
            [
                "| label | path | archived_path | size_before |",
                "|---|---|---|---:|",
            ]
        )
        for item in cleaned_logs:
            lines.append(
                f"| {item['label']} | {item['path']} | {item['archived_path']} | {item['size_before']} |"
            )
    else:
        lines.append("_no stale logs moved_")
    lines.extend(
        [
            "",
            "## Post Status",
            "",
        ]
    )
    for action in actions:
        lines.append(f"### {action.label}")
        lines.append("")
        snippet = status_snippet(action.label)
        if snippet:
            lines.append("```text")
            lines.append(snippet)
            lines.append("```")
        else:
            lines.append("_no status output_")
        lines.append("")
    md_path.write_text("\n".join(lines), encoding="utf-8")
    return {"json": str(json_path), "markdown": str(md_path)}


def cleanup_stale_logs(report_dir: Path) -> list[dict[str, Any]]:
    archived_dir = report_dir / "stale_logs"
    archived_dir.mkdir(parents=True, exist_ok=True)
    cleaned: list[dict[str, Any]] = []

    for label, paths in KNOWN_STALE_LOGS.items():
        for path in paths:
            if not path.exists():
                continue
            size_before = path.stat().st_size
            archived = archived_dir / f"{label}.{path.name}"
            if archived.exists():
                archived = archived_dir / f"{label}.{stamp_now()}.{path.name}"
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(path), str(archived))
            path.touch()
            cleaned.append(
                {
                    "label": label,
                    "path": str(path),
                    "archived_path": str(archived),
                    "size_before": size_before,
                    "size_after": path.stat().st_size,
                }
            )
    return cleaned


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Repair stale QAI launch agents found via sysdiagnose.")
    parser.add_argument(
        "--sysdiagnose",
        default="/private/var/tmp/sysdiagnose_2026.03.18_18-09-08+0300_macOS_Mac_25D2128.tar.gz",
        help="Original sysdiagnose archive path for attribution in the report.",
    )
    parser.add_argument(
        "--labels",
        nargs="*",
        help="Optional explicit launch agent labels to repair. Defaults to the known problematic set.",
    )
    return parser.parse_args(argv)


def target_paths(explicit_labels: list[str] | None) -> list[Path]:
    labels = explicit_labels or sorted(
        set(PATCH_LABELS) | set(DISABLE_REASONS)
    )
    return [LAUNCH_AGENTS_DIR / f"{label}.plist" for label in labels if (LAUNCH_AGENTS_DIR / f"{label}.plist").exists()]


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    stamp = stamp_now()
    report_dir = REPORT_ROOT / stamp
    backup_dir = report_dir / "backups"
    quarantine_dir = DISABLED_DIR / f"qai_sysdiagnose_{stamp}"
    LOG_ROOT.mkdir(parents=True, exist_ok=True)

    actions = [
        repair_launchagent(path, backup_dir=backup_dir, quarantine_dir=quarantine_dir)
        for path in target_paths(args.labels)
    ]
    cleaned_logs = cleanup_stale_logs(report_dir)
    report_paths = write_report(report_dir, args.sysdiagnose, actions, cleaned_logs)
    print(
        json.dumps(
            {
                "status": "ok",
                "timestamp": utc_now(),
                "report_paths": report_paths,
                "quarantine_dir": str(quarantine_dir),
                "cleaned_logs": cleaned_logs,
                "actions": [action.to_dict() for action in actions],
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
