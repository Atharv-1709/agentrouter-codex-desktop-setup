import json
import os
from pathlib import Path, PureWindowsPath
import shutil
import subprocess
import sys
import tempfile
import tomllib
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import merge_config_windows as merge  # noqa: E402


class WindowsMergeTests(unittest.TestCase):
    def setUp(self):
        self.resolver = r"C:\Users\Example\Scripts\credential-windows.ps1"

    def test_adds_agentrouter_and_preserves_unrelated_configuration(self):
        original = '''model = "other-model"
model_provider = "other"
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[features]
web_search = true

[mcp_servers.docs]
command = "docs-mcp"
args = ["--safe"]

[model_providers.other]
name = "Other"
base_url = "https://example.test/v1"
wire_api = "responses"
'''
        result = merge.merge_config(original, model="gpt-6-astra", wire_api="responses", resolver_path=self.resolver)
        parsed = tomllib.loads(result)
        self.assertEqual(parsed["model"], "gpt-6-astra")
        self.assertEqual(parsed["model_provider"], "agentrouter")
        self.assertEqual(parsed["approval_policy"], "on-request")
        self.assertEqual(parsed["sandbox_mode"], "workspace-write")
        self.assertTrue(parsed["features"]["web_search"])
        self.assertEqual(parsed["mcp_servers"]["docs"]["args"], ["--safe"])
        self.assertEqual(parsed["model_providers"]["other"]["base_url"], "https://example.test/v1")
        provider = parsed["model_providers"]["agentrouter"]
        self.assertEqual(provider["base_url"], "https://co.agentrouter.org/v1")
        self.assertEqual(provider["wire_api"], "responses")
        self.assertEqual(provider["auth"]["command"], "pwsh.exe")
        self.assertIn("credential-windows.ps1", provider["auth"]["args"][-2])
        self.assertNotIn("AGENTROUTER_API_KEY", result)
        self.assertIn('"gpt-5.5"', result)

    def test_replaces_duplicate_provider_without_duplicate_sections(self):
        original = '''model = "old"
model_provider = "agentrouter"
[model_providers.agentrouter]
name = "Old"
base_url = "https://old.test"
[model_providers.agentrouter.auth]
command = "old-command"
[model_providers.other]
name = "Keep"
'''
        result = merge.merge_config(original, model="gpt-5.5", wire_api="responses", resolver_path=self.resolver)
        parsed = tomllib.loads(result)
        self.assertEqual(parsed["model"], "gpt-5.5")
        self.assertEqual(parsed["model_providers"]["other"]["name"], "Keep")
        self.assertEqual(result.count("[model_providers.agentrouter]"), 1)
        self.assertEqual(result.count("[model_providers.agentrouter.auth]"), 1)

    def test_chat_option_is_explicit_and_merge_is_valid_toml(self):
        result = merge.merge_config("", model="gpt-6-astra", wire_api="chat", resolver_path=self.resolver)
        self.assertEqual(tomllib.loads(result)["model_providers"]["agentrouter"]["wire_api"], "chat")
        self.assertNotIn("credential unavailable", result)
        self.assertNotIn("AGENTROUTER_API_KEY", result)

    def test_rejects_bad_model_wire_protocol_and_invalid_toml(self):
        with self.assertRaises(ValueError):
            merge.merge_config("", model="gpt-4o", wire_api="responses", resolver_path=self.resolver)
        with self.assertRaises(ValueError):
            merge.merge_config("", model="gpt-5.5", wire_api="chat-completions", resolver_path=self.resolver)
        with self.assertRaises(ValueError):
            merge.merge_config("model = [", model="gpt-5.5", wire_api="responses", resolver_path=self.resolver)

    def test_backup_and_rollback_restore_config_and_save_recovery(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as temp:
            config = Path(temp) / ".codex" / "config.toml"
            config.parent.mkdir()
            before = 'approval_policy = "on-request"\n'
            config.write_text(before, encoding="utf-8")
            backup = merge.backup_config(config)
            self.assertTrue(backup.is_file())
            self.assertTrue(merge._metadata_path(backup).is_file())
            self.assertTrue(json.loads(merge._metadata_path(backup).read_text())["config_existed"])
            config.write_text('model = "changed"\n', encoding="utf-8")
            recovery = merge.rollback_config(config, backup)
            self.assertEqual(config.read_text(encoding="utf-8"), before)
            self.assertIsNotNone(recovery)
            self.assertEqual(recovery.read_text(encoding="utf-8"), 'model = "changed"\n')

    def test_install_creates_timestamped_backup_before_replacing_config(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as temp:
            config = Path(temp) / "config.toml"
            before = 'approval_policy = "on-request"\n'
            config.write_text(before, encoding="utf-8")
            merged = merge.merge_config(before, model="gpt-6-astra", wire_api="responses", resolver_path=self.resolver)
            backup = merge.install_config(config, merged)
            self.assertEqual(backup.read_text(encoding="utf-8"), before)
            self.assertRegex(backup.name, r"^config\.toml\.pre-agentrouter\.\d{4}-\d{2}-\d{2}T\d{6}\.\d{9}$")
            self.assertEqual(tomllib.loads(config.read_text(encoding="utf-8"))["model"], "gpt-6-astra")

    def test_new_config_rollback_removes_file_and_saves_recovery(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as temp:
            config = Path(temp) / "config.toml"
            backup = merge.backup_config(config)
            self.assertFalse(json.loads(merge._metadata_path(backup).read_text())["config_existed"])
            config.write_text('model = "new"\n', encoding="utf-8")
            recovery = merge.rollback_config(config, backup)
            self.assertFalse(config.exists())
            self.assertEqual(recovery.read_text(encoding="utf-8"), 'model = "new"\n')

    def test_missing_or_invalid_backup_refuses_rollback_without_mutating_config(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as temp:
            config = Path(temp) / "config.toml"
            current = 'model = "current"\n'
            config.write_text(current, encoding="utf-8")
            with self.assertRaises(ValueError):
                merge.rollback_config(config, Path(temp) / "missing")
            self.assertEqual(config.read_text(encoding="utf-8"), current)
            backup = merge.backup_config(config)
            backup.write_text("model = [", encoding="utf-8")
            with self.assertRaises(ValueError):
                merge.rollback_config(config, backup)
            self.assertEqual(config.read_text(encoding="utf-8"), current)

    def test_windows_path_detection_and_config_home(self):
        self.assertTrue(merge.is_windows_absolute(r"C:\Users\Example\.codex\config.toml"))
        self.assertFalse(merge.is_windows_absolute(r".codex\config.toml"))
        self.assertEqual(merge.detect_config_path(r"C:\CodexHome\config.toml"), Path(r"C:\CodexHome\config.toml"))

    def test_dry_run_cli_does_not_create_config_or_backup(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as temp:
            config = Path(temp) / "new" / "config.toml"
            completed = subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "scripts" / "merge_config_windows.py"),
                    "--config",
                    str(config),
                    "--resolver",
                    self.resolver,
                    "--wire-api",
                    "responses",
                    "--dry-run",
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertIn("gpt-6-astra", completed.stdout)
            self.assertFalse(config.exists())
            self.assertFalse((config.parent / "backups").exists())

    def test_chat_protocol_cli_refuses_to_write(self):
        with tempfile.TemporaryDirectory(dir=ROOT) as temp:
            config = Path(temp) / "config.toml"
            completed = subprocess.run(
                [
                    sys.executable,
                    str(ROOT / "scripts" / "merge_config_windows.py"),
                    "--config",
                    str(config),
                    "--resolver",
                    self.resolver,
                    "--wire-api",
                    "chat",
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(completed.returncode, 0)
            self.assertIn("experimental preview only", completed.stderr)
            self.assertFalse(config.exists())
            self.assertFalse((config.parent / "backups").exists())

    @unittest.skipUnless(os.name == "nt", "requires Windows")
    def test_installer_dry_run_probes_real_python_and_does_not_write_config(self):
        pwsh = shutil.which("pwsh.exe") or shutil.which("pwsh")
        if not pwsh or not shutil.which("codex"):
            self.skipTest("requires PowerShell 7 and Codex CLI")
        with tempfile.TemporaryDirectory() as temp:
            env = os.environ.copy()
            env["CODEX_HOME"] = temp
            completed = subprocess.run(
                [pwsh, "-NoLogo", "-NoProfile", "-File", str(ROOT / "scripts" / "install-windows.ps1"), "-DryRun"],
                check=False,
                capture_output=True,
                text=True,
                env=env,
                timeout=45,
            )
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
            self.assertIn("DRY RUN:", completed.stdout)
            self.assertIn(str(Path(temp) / "config.toml"), completed.stdout)
            self.assertFalse((Path(temp) / "config.toml").exists())
            self.assertFalse((Path(temp) / "backups").exists())

    @unittest.skipUnless(os.name == "nt", "requires Windows Credential Manager")
    def test_credential_manager_dummy_store_retrieve_delete(self):
        pwsh = shutil.which("pwsh.exe") or shutil.which("pwsh")
        if not pwsh:
            self.skipTest("requires PowerShell 7")
        target = "AgentRouter/Codex/python-test-" + uuid.uuid4().hex
        completed = subprocess.run(
            [
                pwsh,
                "-NoLogo",
                "-NoProfile",
                "-NonInteractive",
                "-File",
                str(ROOT / "scripts" / "credential-windows.ps1"),
                "-SelfTest",
                "-TargetName",
                target,
            ],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)
        self.assertIn("PASS: dummy-only Credential Manager round-trip", completed.stdout)
        self.assertNotIn("offline-test-", completed.stdout + completed.stderr)


if __name__ == "__main__":
    unittest.main()
