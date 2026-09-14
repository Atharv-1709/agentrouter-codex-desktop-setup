#!/usr/bin/env python3

import sys
from pathlib import Path
import tomllib
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

from merge_config import merge_config  # noqa: E402


class MergeConfigTests(unittest.TestCase):
    def test_empty_config(self):
        result = merge_config("")
        parsed = tomllib.loads(result)
        self.assertEqual(parsed["model"], "gpt-6-astra")
        self.assertEqual(parsed["model_provider"], "agentrouter")

    def test_preserves_unrelated_settings(self):
        original = """# Existing configuration
model = \"gpt-5.6-sol\"
approval_policy = \"on-request\"

[features]
web_search = true

[model_providers.other]
name = \"Other\"
base_url = \"https://example.com/v1\"
wire_api = \"responses\"
"""
        parsed = tomllib.loads(merge_config(original))
        self.assertEqual(parsed["approval_policy"], "on-request")
        self.assertTrue(parsed["features"]["web_search"])
        self.assertEqual(parsed["model_providers"]["other"]["name"], "Other")
        self.assertEqual(parsed["model"], "gpt-6-astra")

    def test_replaces_existing_agentrouter_section(self):
        original = """model = \"old-model\"
model_provider = \"agentrouter\"

[model_providers.agentrouter]
name = \"Old AgentRouter\"
base_url = \"https://old.invalid/v1\"
wire_api = \"responses\"

[model_providers.agentrouter.auth]
command = \"old-command\"

[shell_environment_policy]
inherit = \"core\"
"""
        result = merge_config(original)
        parsed = tomllib.loads(result)
        provider = parsed["model_providers"]["agentrouter"]
        self.assertEqual(provider["name"], "AgentRouter")
        self.assertEqual(provider["base_url"], "https://agentrouter.org/v1")
        self.assertEqual(
            parsed["shell_environment_policy"]["inherit"],
            "core",
        )
        self.assertEqual(result.count("[model_providers.agentrouter]"), 1)

    def test_rejects_invalid_existing_toml(self):
        with self.assertRaises(SystemExit):
            merge_config("model = [")


if __name__ == "__main__":
    unittest.main()
