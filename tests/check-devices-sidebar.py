#!/usr/bin/env python3
"""Exercise real application UI with disposable volumes and strict fake disk tools.

Requires QtTest. Run after cargo build; optional first argument selects the binary.
No mount/unmount/eject command is ever forwarded to a system tool.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

FAKE_TOOL = r"""#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
root = Path(os.environ["LOAF_DEVICE_TEST_ROOT"])
state_file = root / "state.json"
state = json.loads(state_file.read_text())
def save():
    temporary = state_file.with_suffix(".tmp")
    temporary.write_text(json.dumps(state))
    temporary.replace(state_file)
if Path(sys.argv[0]).name == "secret-tool":
    sys.exit(1)
if Path(sys.argv[0]).name == "lsblk":
    children = []
    for name in ["mounted", "success", "fail", "cancel", "view", "tab", "pc", "gone", "locked", "unlock-fail"]:
        if name in state["removed"]:
            continue
        encrypted = name in ["locked", "unlock-fail"]
        path = "/dev/loaf-test-" + name
        node = {"name": "loaf-test-" + name, "path": path,
                "label": "Test volume" if name in ["mounted", "success"] else name,
                "mountpoints": [str(root / name), "/var/log"] if name in state["mounted"] else [],
                "fstype": "crypto_LUKS" if encrypted else "ext4", "size": 20000000000, "type": "part"}
        if encrypted and name in state["unlocked"]:
            node["children"] = [{"name": "loaf-test-clear-" + name, "path": "/dev/loaf-test-clear-" + name,
                "label": name, "fstype": "ext4", "type": "crypt", "size": 20000000000,
                "mountpoints": [str(root / name)] if name in state["mounted"] else []}]
        children.append(node)
    print(json.dumps({"blockdevices": [{"name": "loaf-test-disk", "path": "/dev/loaf-test-disk",
        "type": "disk", "size": 200000000000, "rm": True, "tran": "usb", "children": children}]}))
    sys.exit(0)
args = sys.argv[1:]
if len(args) < 3 or args[0] not in ["mount", "unlock"] or args[1] != "-b" or not args[2].startswith("/dev/loaf-test-"):
    sys.exit("Blocked unsupported fake disk command")
command, device = args[0], args[2]
with (root / "calls.jsonl").open("a") as stream:
    stream.write(json.dumps({"command": command, "device": device}) + "\n")
name = device.removeprefix("/dev/loaf-test-").removeprefix("clear-")
if name == "gone":
    state["removed"].append(name)
    save()
time.sleep(0.3)
if command == "unlock":
    if sys.stdin.read() != "test-pass":
        sys.exit("Incorrect passphrase")
    state["unlocked"].append(name)
    save()
    print("Unlocked " + device + " as /dev/loaf-test-clear-" + name + ".")
else:
    if name in ["fail", "unlock-fail"]:
        sys.exit("Permission denied (simulated)")
    state["mounted"].append(name)
    save()
    print("Mount operation completed (no path in this message)")
"""


def main():
    root = Path(__file__).resolve().parents[1]
    binary = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root / "target/debug/loaf"
    with tempfile.TemporaryDirectory(prefix="loaf-devices-") as directory:
        sandbox = Path(directory)
        for name in ["mounted", "success", "fail", "cancel", "view", "tab", "pc", "gone", "locked", "unlock-fail", "stay", "other"]:
            (sandbox / name).mkdir()
        (sandbox / "state.json").write_text(json.dumps({"mounted": ["mounted"], "unlocked": [], "removed": []}))
        tools = sandbox / "bin"
        tools.mkdir()
        for tool in ["lsblk", "udisksctl", "secret-tool"]:
            path = tools / tool
            path.write_text(FAKE_TOOL)
            path.chmod(0o755)
        source = (root / "qml/main.qml").read_text().replace("import app.loaf", "import app.loaf\nimport QtTest", 1)
        source = source.rsplit("}", 1)[0] + (root / "tests/devices-navigation.inc.qml").read_text() + "}\n"
        probe = sandbox / "main.qml"
        probe.write_text(source)
        config = sandbox / "config/loaf/config.json"
        config.parent.mkdir(parents=True)
        config.write_text(json.dumps({"devicesTestRoot": str(sandbox)}))
        env = os.environ.copy()
        env.update(PATH=str(tools) + os.pathsep + env.get("PATH", os.defpath),
                   XDG_CONFIG_HOME=str(sandbox / "config"), QT_QPA_PLATFORM="offscreen",
                   QT_QUICK_CONTROLS_STYLE="Basic",
                   QT_FORCE_STDERR_LOGGING="1", LOAF_QML=str(probe), LOAF_DEVICE_TEST_ROOT=str(sandbox))
        result = subprocess.run([str(binary), "--new-window"], env=env,
                                capture_output=True, text=True, timeout=50)
        output = result.stdout + result.stderr
        if result.returncode or "DEVICES_UI_TEST_ALL_PASS" not in output or "DEVICES_UI_TEST_FAIL" in output or "ReferenceError:" in output:
            raise AssertionError(output)
        calls = [json.loads(line) for line in (sandbox / "calls.jsonl").read_text().splitlines()]
        assert sum(c["device"] == "/dev/loaf-test-success" and c["command"] == "mount" for c in calls) == 1, calls
        print("\n".join(line for line in output.splitlines() if "DEVICES_" in line))
        print("Fake command log confirms duplicate clicks issue only one mount request")


if __name__ == "__main__":
    main()
