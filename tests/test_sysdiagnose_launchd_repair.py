from __future__ import annotations

import importlib.util
import plistlib
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "ops" / "qai_sysdiagnose_launchd_repair.py"
SPEC = importlib.util.spec_from_file_location("qai_sysdiagnose_launchd_repair", MODULE_PATH)
assert SPEC is not None
assert SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def test_expand_vars_replaces_home_and_user(tmp_path):
    value = "$HOME/Library/Logs/${HOME}/$USER"
    expanded = MODULE.expand_vars(value, home=tmp_path / "home", user="tester")
    assert expanded == f"{tmp_path / 'home'}/Library/Logs/{tmp_path / 'home'}/tester"


def test_patch_system_rotate_updates_paths(tmp_path):
    home = tmp_path / "home"
    data = {
        "Label": "com.qai.system.rotate",
        "ProgramArguments": [
            "/bin/bash",
            "-lc",
            'source "$HOME/.qai_system_monitor/env.conf" 2>/dev/null; exec "$HOME/bin/qai_rotate.sh"',
        ],
        "StandardOutPath": "$HOME/Library/Logs/qai_system_rotate.out.log",
        "StandardErrorPath": "$HOME/Library/Logs/qai_system_rotate.err.log",
    }

    patched = MODULE.patch_system_rotate(data, home=home)

    assert patched["StandardOutPath"] == str(home / "Library" / "Logs" / "qai_system_rotate.out.log")
    assert patched["StandardErrorPath"] == str(home / "Library" / "Logs" / "qai_system_rotate.err.log")
    assert str(home / ".qai_system_monitor" / "env.conf") in patched["ProgramArguments"][2]


def test_rebuild_sshagent_is_valid_and_not_keepalive(tmp_path):
    home = tmp_path / "home"
    plist = MODULE.rebuild_sshagent(home=home)

    assert plist["Label"] == "com.qai.sshagent"
    assert plist["KeepAlive"] is False
    assert plist["RunAtLoad"] is True
    assert plist["StandardOutPath"] == str(home / "Library" / "Logs" / "com.qai.sshagent.out.log")
    dumped = plistlib.dumps(plist)
    loaded = plistlib.loads(dumped)
    assert loaded["Label"] == "com.qai.sshagent"


def test_classify_disables_legacy_labels_before_parse_errors():
    action, reason = MODULE.classify("com.qai.guardian", data=None, parse_error="broken")
    assert action == "disable"
    assert reason == "legacy-guardian-disabled-to-stop-respawn-noise"
