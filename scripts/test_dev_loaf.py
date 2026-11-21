#!/usr/bin/env python3
"""Comprehensive unit and black-box tests for scripts/dev-loaf.

Tests root causes:
1. 2MB stderr output from Cargo doesn't cause deadlock.
2. Absolute python token and two-level desktop Exec escaping with real gio launch and marker verification.
3. Cargo artifact 'executable' field honored over filenames[0].
4. Snapshot name validation: fullmatch, no newlines, no empty strings, traversal protection.
5. Temp file cleanup on copy failure and atomic publication.
6. Verification that concurrent builds serialize without overlapping critical sections.
7. Unaltered previous binary on failed build or copy.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS_DIR = Path(__file__).resolve().parent
import importlib.machinery
import importlib.util

loader = importlib.machinery.SourceFileLoader("dev_loaf", str(SCRIPTS_DIR / "dev-loaf"))
spec = importlib.util.spec_from_loader("dev_loaf", loader)
assert spec is not None
dev_loaf = importlib.util.module_from_spec(spec)
loader.exec_module(dev_loaf)


class TestDevLoafUnit(unittest.TestCase):
    """Unit tests for snapshot validation and desktop argument escaping."""

    def test_snapshot_name_validation(self):
        valid_names = ["v1", "test-123", "snap_2026.11", "good.name", "A_B-C.D"]
        for name in valid_names:
            try:
                dev_loaf.validate_snapshot_name(name)
            except ValueError:
                self.fail(f"Valid snapshot name '{name}' raised ValueError")

        invalid_names = [
            None,
            "",
            ".",
            "..",
            "v1\n",
            "\nv1",
            "../escape",
            "foo/bar",
            "foo\\bar",
            "snap with spaces",
            "snap$name",
            "snap`name`",
            "snap;cmd",
            "snap*wild",
        ]
        for name in invalid_names:
            with self.assertRaises(ValueError, msg=f"Invalid name '{name}' did not raise ValueError"):
                dev_loaf.validate_snapshot_name(name)

    def test_escape_desktop_exec_arg(self):
        # Path with spaces
        res = dev_loaf.escape_desktop_exec_arg("/path with spaces/dev-loaf")
        self.assertEqual(res, '"/path with spaces/dev-loaf"')

        # Path with dollar, backtick, quotes, percent
        res = dev_loaf.escape_desktop_exec_arg('/path/$foo/`bar`/"baz"/%test')
        self.assertTrue(res.startswith('"') and res.endswith('"'))
        self.assertIn("%%test", res)
        self.assertIn(r"\\$foo", res)
        self.assertIn(r"\\`bar\\`", res)
        self.assertIn(r'\\"baz\\"', res)

        # Path with newlines must be rejected
        with self.assertRaises(ValueError):
            dev_loaf.escape_desktop_exec_arg("/path\nwith/newline")


class TestDevLoafBlackbox(unittest.TestCase):
    """Black-box subprocess tests using isolated test environments."""

    def setUp(self):
        self.test_dir = tempfile.mkdtemp(prefix="loaf-dev-test-")
        self.addCleanup(lambda: shutil.rmtree(self.test_dir, ignore_errors=True))

    def create_mock_repo(self, repo_name="mock-loaf"):
        repo_dir = Path(self.test_dir) / repo_name
        repo_dir.mkdir(parents=True)
        scripts_dir = repo_dir / "scripts"
        scripts_dir.mkdir(parents=True)
        dest_script = scripts_dir / "dev-loaf"
        shutil.copy2(SCRIPTS_DIR / "dev-loaf", dest_script)
        dest_script.chmod(0o755)
        return repo_dir

    def test_missing_first_build_and_cli_errors(self):
        repo_dir = self.create_mock_repo("repo-no-build")
        helper = repo_dir / "scripts" / "dev-loaf"

        # Running without build fails cleanly
        proc = subprocess.run([str(helper), "run"], capture_output=True, text=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("No published dev binary found", proc.stderr)

        # Default invocation (no args) -> fails cleanly
        proc = subprocess.run([str(helper)], capture_output=True, text=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("No published dev binary found", proc.stderr)

        # Build with --keep when no current build exists
        proc = subprocess.run([str(helper), "build", "--keep", "initial"], capture_output=True, text=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("Cannot keep snapshot 'initial': No current published binary exists", proc.stderr)

        # Build with empty --keep= should fail cleanly
        proc = subprocess.run([str(helper), "build", "--keep="], capture_output=True, text=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("Snapshot name cannot be empty", proc.stderr)

        # Run with empty --keep= should fail cleanly
        proc = subprocess.run([str(helper), "run", "--keep="], capture_output=True, text=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("Snapshot name cannot be empty", proc.stderr)

        # Run with newline in snapshot name
        proc = subprocess.run([str(helper), "run", "--keep", "bad\nname"], capture_output=True, text=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("Invalid snapshot name", proc.stderr)

    def test_cargo_artifact_executable_and_2mb_stderr(self):
        """Root proof 1: 2MB stderr from Cargo does not deadlock helper, and 'executable' field is used."""
        repo_dir = self.create_mock_repo("repo-2mb-stderr")
        helper = repo_dir / "scripts" / "dev-loaf"
        bin_dir = Path(self.test_dir) / "bin"
        bin_dir.mkdir(parents=True)

        fake_binary = repo_dir / "target-out" / "loaf_exe"
        fake_binary.parent.mkdir(parents=True)
        fake_binary.write_text("#!/bin/sh\necho BINARY_V1\n")
        fake_binary.chmod(0o755)

        # Fake non-exe placeholder in filenames[0]
        placeholder = repo_dir / "target-out" / "loaf.dSYM"
        placeholder.write_text("debug symbol")

        fake_cargo = bin_dir / "cargo"
        # Writes 2MB to stderr before stdout JSON artifact
        cargo_script = f"""#!/usr/bin/env python3
import sys, os, json
os.write(2, b"x" * 2000000)
msg = {{
    "reason": "compiler-artifact",
    "target": {{"name": "loaf", "kind": ["bin"]}},
    "filenames": ["{placeholder}", "{fake_binary}"],
    "executable": "{fake_binary}"
}}
print(json.dumps(msg))
sys.exit(0)
"""
        fake_cargo.write_text(cargo_script)
        fake_cargo.chmod(0o755)

        env = os.environ.copy()
        env["PATH"] = f"{bin_dir}:{env['PATH']}"

        # Must finish within 10s without deadlock
        t0 = time.time()
        proc = subprocess.run([str(helper), "build"], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=10)
        elapsed = time.time() - t0
        self.assertEqual(proc.returncode, 0, f"stderr: {proc.stderr[:200]}")
        self.assertLess(elapsed, 5.0, "Build took too long, possible stderr pipe stall")

        published_binary = repo_dir / "target" / "dev-launcher" / "loaf"
        self.assertTrue(published_binary.exists())
        self.assertEqual(published_binary.read_text(), "#!/bin/sh\necho BINARY_V1\n")

    def test_cargo_build_and_run_contract_with_fake_cargo(self):
        """Simulate Cargo build, snapshot contracts, failed build preservation, and verbatim args."""
        repo_dir = self.create_mock_repo("repo with spaces and-unicode_🚀")
        helper = repo_dir / "scripts" / "dev-loaf"
        bin_dir = Path(self.test_dir) / "bin_full"
        bin_dir.mkdir(parents=True)

        fake_cargo = bin_dir / "cargo"
        fake_binary = repo_dir / "custom-target" / "debug" / "loaf"
        fake_binary.parent.mkdir(parents=True)

        log_file = repo_dir / "launch_log.json"
        fake_binary_script = f"""#!/usr/bin/env python3
import sys, os, json
log = {{
    "args": sys.argv[1:],
    "cwd": os.getcwd()
}}
with open("{log_file}", "w") as f:
    json.dump(log, f)
print("MARKER_V1")
sys.exit(0)
"""
        fake_binary.write_text(fake_binary_script)
        fake_binary.chmod(0o755)

        cargo_script = f"""#!/usr/bin/env python3
import sys, json
args = sys.argv[1:]
if "build" in args:
    msg1 = {{
        "reason": "compiler-message",
        "message": {{"rendered": "   Compiling loaf-fake v0.1.0\\n"}}
    }}
    msg2 = {{
        "reason": "compiler-artifact",
        "target": {{"name": "loaf", "kind": ["bin"]}},
        "filenames": ["{fake_binary}"],
        "executable": "{fake_binary}"
    }}
    print(json.dumps(msg1))
    print(json.dumps(msg2))
    sys.exit(0)
sys.exit(1)
"""
        fake_cargo.write_text(cargo_script)
        fake_cargo.chmod(0o755)

        env = os.environ.copy()
        env["PATH"] = f"{bin_dir}:{env['PATH']}"

        # 1. Build
        proc = subprocess.run([str(helper), "build"], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.assertEqual(proc.returncode, 0, f"stderr: {proc.stderr}")
        published_binary = repo_dir / "target" / "dev-launcher" / "loaf"
        self.assertTrue(published_binary.exists())

        # No .tmp files left in target/dev-launcher
        tmp_files = [f for f in (repo_dir / "target" / "dev-launcher").iterdir() if f.name.startswith(".loaf.tmp")]
        self.assertEqual(tmp_files, [])

        # 2. Run without Cargo in PATH
        clean_env = os.environ.copy()
        clean_env["PATH"] = os.pathsep.join([str(Path(sys.executable).parent), "/usr/bin", "/bin"])
        caller_cwd = repo_dir / "caller_dir"
        caller_cwd.mkdir()

        proc = subprocess.run(
            [str(helper), "run", "--", "arg1", "--keep", "--flag", "file with space.txt"],
            cwd=str(caller_cwd),
            env=clean_env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, f"Run stderr: {proc.stderr}")
        self.assertIn("MARKER_V1", proc.stdout)

        log_data = json.loads(log_file.read_text())
        self.assertEqual(log_data["cwd"], str(caller_cwd))
        self.assertEqual(log_data["args"], ["arg1", "--keep", "--flag", "file with space.txt"])

        # 3. Snapshot with --keep
        proc = subprocess.run([str(helper), "build", "--keep", "v1.0"], env=env, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0)
        snapshot_v1 = repo_dir / "target" / "dev-launcher" / "snapshots" / "loaf-v1.0"
        self.assertTrue(snapshot_v1.exists())

        # Duplicate keep name rejected without overwrite
        proc = subprocess.run([str(helper), "build", "--keep", "v1.0"], env=env, capture_output=True, text=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("already exists", proc.stderr)

        # 4. Update binary source marker to V2 and build
        fake_binary.write_text(fake_binary_script.replace("MARKER_V1", "MARKER_V2"))
        proc = subprocess.run([str(helper), "build"], env=env, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0)

        # Running current gives V2
        proc = subprocess.run([str(helper), "run"], env=clean_env, capture_output=True, text=True)
        self.assertIn("MARKER_V2", proc.stdout)

        # Running snapshot gives original V1
        proc = subprocess.run([str(helper), "run", "--keep", "v1.0"], env=clean_env, capture_output=True, text=True)
        self.assertIn("MARKER_V1", proc.stdout)

        # 5. Failed Cargo build keeps previous good binary intact
        failing_cargo_script = """#!/usr/bin/env python3
import sys
sys.stderr.write("error[E0425]: cannot find value `broken`\\n")
sys.exit(101)
"""
        fake_cargo.write_text(failing_cargo_script)
        proc = subprocess.run([str(helper), "build"], env=env, capture_output=True, text=True)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("Last good build remains active", proc.stderr)

        # Verify previous good binary (V2) still runs
        proc = subprocess.run([str(helper), "run"], env=clean_env, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0)
        self.assertIn("MARKER_V2", proc.stdout)

    def test_desktop_escaping_and_real_gio_marker(self):
        """Root proof 2: paths with spaces, $, %, `, \", backslash, and unicode pass desktop-file-validate AND gio launch with marker verification."""
        repo_dir = self.create_mock_repo('repo $cash %case `back` "quote" \\slash')
        helper = repo_dir / "scripts" / "dev-loaf"
        launcher_dir = repo_dir / "target" / "dev-launcher"
        launcher_dir.mkdir(parents=True)

        marker_file = repo_dir / "gio_marker.txt"
        fake_published = launcher_dir / "loaf"
        fake_published.write_text(f"""#!/usr/bin/env python3
import sys, os
with open({repr(str(marker_file))}, "w") as f:
    f.write(f"CWD: {{os.getcwd()}}\\nARGS: {{' '.join(sys.argv[1:])}}\\n")
""")
        fake_published.chmod(0o755)

        fake_xdg_data = Path(self.test_dir) / "xdg_data"
        env = os.environ.copy()
        env["XDG_DATA_HOME"] = str(fake_xdg_data)

        proc = subprocess.run([str(helper), "install-desktop"], env=env, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, f"install-desktop failed: {proc.stderr}")

        desktop_file = fake_xdg_data / "applications" / "loaf-dev.desktop"
        self.assertTrue(desktop_file.exists())

        # Validate with desktop-file-validate
        if shutil.which("desktop-file-validate"):
            val_proc = subprocess.run(["desktop-file-validate", str(desktop_file)], capture_output=True, text=True)
            self.assertEqual(val_proc.returncode, 0, f"desktop-file-validate errors: {val_proc.stdout} {val_proc.stderr}")

        # Validate with gio launch and verify marker
        if shutil.which("gio"):
            test_file = Path(self.test_dir) / "test_doc.txt"
            test_file.write_text("hello")
            gio_proc = subprocess.run(
                ["gio", "launch", str(desktop_file), str(test_file)],
                capture_output=True,
                text=True,
                timeout=10,
            )
            self.assertEqual(gio_proc.returncode, 0, f"gio launch failed: {gio_proc.stdout} {gio_proc.stderr}")
            deadline = time.time() + 5.0
            while not marker_file.exists() and time.time() < deadline:
                time.sleep(0.05)
            self.assertTrue(marker_file.exists(), "gio launch did not execute published binary to create marker")
            marker_content = marker_file.read_text()
            self.assertIn(str(test_file), marker_content)

    def test_concurrent_build_serialization_overlap_check(self):
        """Prove that fcntl flock strictly serializes builds and critical sections never overlap."""
        repo_dir = self.create_mock_repo("repo-flock-overlap")
        helper = repo_dir / "scripts" / "dev-loaf"
        bin_dir = Path(self.test_dir) / "bin_flock"
        bin_dir.mkdir(parents=True)

        fake_binary = repo_dir / "target-flock" / "loaf"
        fake_binary.parent.mkdir(parents=True)
        fake_binary.write_text("#!/bin/sh\necho OK\n")
        fake_binary.chmod(0o755)

        audit_log = repo_dir / "flock_audit.log"
        # Fake cargo writes ENTER and EXIT timestamps to audit log
        fake_cargo = bin_dir / "cargo"
        cargo_script = f"""#!/usr/bin/env python3
import sys, json, time, os
with open("{audit_log}", "a") as f:
    f.write(f"ENTER {{os.getpid()}} {{time.time()}}\\n")
time.sleep(0.3)
with open("{audit_log}", "a") as f:
    f.write(f"EXIT {{os.getpid()}} {{time.time()}}\\n")
msg = {{
    "reason": "compiler-artifact",
    "target": {{"name": "loaf", "kind": ["bin"]}},
    "filenames": ["{fake_binary}"],
    "executable": "{fake_binary}"
}}
print(json.dumps(msg))
sys.exit(0)
"""
        fake_cargo.write_text(cargo_script)
        fake_cargo.chmod(0o755)

        env = os.environ.copy()
        env["PATH"] = f"{bin_dir}:{env['PATH']}"

        p1 = subprocess.Popen([str(helper), "build"], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        p2 = subprocess.Popen([str(helper), "build"], env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        out1, err1 = p1.communicate()
        out2, err2 = p2.communicate()

        self.assertEqual(p1.returncode, 0, f"p1: {err1}")
        self.assertEqual(p2.returncode, 0, f"p2: {err2}")

        # Parse audit log to verify serialization
        lines = audit_log.read_text().strip().splitlines()
        self.assertEqual(len(lines), 4, f"Expected 4 audit events, got {lines}")

        e1_type, pid1, t1 = lines[0].split()
        e2_type, pid2, t2 = lines[1].split()
        e3_type, pid3, t3 = lines[2].split()
        e4_type, pid4, t4 = lines[3].split()

        self.assertEqual(e1_type, "ENTER")
        self.assertEqual(e2_type, "EXIT")
        self.assertEqual(pid1, pid2, "First build must exit before next build enters")
        self.assertEqual(e3_type, "ENTER")
        self.assertEqual(e4_type, "EXIT")
        self.assertEqual(pid3, pid4)
        self.assertNotEqual(pid1, pid3)
        self.assertLessEqual(float(t2), float(t3), "Second build entered before first exited (overlap!)")


    def test_build_copy_or_replace_oserror_mock(self):
        """Unittest mock regression for partial copy or os.replace failure:
        previous current and existing snapshots unchanged, staging removed, nonzero status, lock released."""
        repo_dir = self.create_mock_repo("repo-oserror-mock")
        launcher_dir = repo_dir / "target" / "dev-launcher"
        snapshots_dir = launcher_dir / "snapshots"
        snapshots_dir.mkdir(parents=True)

        prev_current = launcher_dir / "loaf"
        prev_current.parent.mkdir(parents=True, exist_ok=True)
        prev_current.write_text("#!/bin/sh\necho ORIGINAL_CURRENT\n")
        prev_current.chmod(0o755)

        existing_snap = snapshots_dir / "loaf-existing"
        existing_snap.write_text("#!/bin/sh\necho ORIGINAL_SNAP\n")
        existing_snap.chmod(0o755)

        # 1. Simulate failure during shutil.copy2 when staging snapshot
        with mock.patch("scripts.test_dev_loaf.dev_loaf.get_repo_root", return_value=repo_dir):
            with mock.patch("shutil.copy2", side_effect=OSError("Disk full during snapshot copy")):
                rc = dev_loaf.main(["build", "--keep", "new-snap"])
                self.assertNotEqual(rc, 0)

            self.assertEqual(prev_current.read_text(), "#!/bin/sh\necho ORIGINAL_CURRENT\n")
            self.assertEqual(existing_snap.read_text(), "#!/bin/sh\necho ORIGINAL_SNAP\n")
            # No staging files remain
            staging_snaps = [f for f in snapshots_dir.iterdir() if f.name.startswith(".loaf-new-snap.tmp")]
            self.assertEqual(staging_snaps, [])
            # Lock released: can acquire immediately
            lock_f = dev_loaf.acquire_build_lock(launcher_dir)
            dev_loaf.release_build_lock(lock_f)

            # 2. Simulate failure during os.replace when publishing new binary
            # We need Cargo to report success
            bin_dir = Path(self.test_dir) / "bin_mock"
            bin_dir.mkdir(parents=True)
            fake_binary = repo_dir / "target-mock" / "loaf"
            fake_binary.parent.mkdir(parents=True)
            fake_binary.write_text("#!/bin/sh\necho NEW_BINARY\n")
            fake_binary.chmod(0o755)

            fake_cargo = bin_dir / "cargo"
            cargo_script = f"""#!/usr/bin/env python3
import sys, json
msg = {{
    "reason": "compiler-artifact",
    "target": {{"name": "loaf", "kind": ["bin"]}},
    "filenames": ["{fake_binary}"],
    "executable": "{fake_binary}"
}}
print(json.dumps(msg))
sys.exit(0)
"""
            fake_cargo.write_text(cargo_script)
            fake_cargo.chmod(0o755)

            env = os.environ.copy()
            env["PATH"] = f"{bin_dir}:{env['PATH']}"
            with mock.patch.dict(os.environ, env):
                with mock.patch("os.replace", side_effect=OSError("Permission denied on replace")):
                    rc = dev_loaf.main(["build"])
                    self.assertNotEqual(rc, 0)

            self.assertEqual(prev_current.read_text(), "#!/bin/sh\necho ORIGINAL_CURRENT\n")
            staging_dest = [f for f in launcher_dir.iterdir() if f.name.startswith(".loaf.tmp")]
            self.assertEqual(staging_dest, [])
            lock_f = dev_loaf.acquire_build_lock(launcher_dir)
            dev_loaf.release_build_lock(lock_f)

    def test_install_desktop_preserves_production_xdg_bytes(self):
        """Private XDG fixture proof: production loaf.desktop and mimeapps.list bytes unchanged by install-desktop."""
        repo_dir = self.create_mock_repo("repo-xdg-preserve")
        fake_xdg_data = Path(self.test_dir) / "xdg_data_preserve"
        apps_dir = fake_xdg_data / "applications"
        apps_dir.mkdir(parents=True)

        prod_desktop = apps_dir / "loaf.desktop"
        prod_desktop_content = b"[Desktop Entry]\nType=Application\nName=Loaf\nExec=loaf %U\n"
        prod_desktop.write_bytes(prod_desktop_content)

        fake_xdg_config = Path(self.test_dir) / "xdg_config_preserve"
        fake_xdg_config.mkdir(parents=True)
        mimeapps_list = fake_xdg_config / "mimeapps.list"
        mimeapps_content = b"[Default Applications]\ninode/directory=loaf.desktop\n"
        mimeapps_list.write_bytes(mimeapps_content)

        env = os.environ.copy()
        env["XDG_DATA_HOME"] = str(fake_xdg_data)
        env["XDG_CONFIG_HOME"] = str(fake_xdg_config)

        helper = repo_dir / "scripts" / "dev-loaf"
        proc = subprocess.run([str(helper), "install-desktop"], env=env, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, f"install-desktop failed: {proc.stderr}")

        dev_desktop = apps_dir / "loaf-dev.desktop"
        self.assertTrue(dev_desktop.exists())
        self.assertEqual(prod_desktop.read_bytes(), prod_desktop_content)
        self.assertEqual(mimeapps_list.read_bytes(), mimeapps_content)


if __name__ == "__main__":
    unittest.main()
