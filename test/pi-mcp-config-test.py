#!/usr/bin/env python3
"""Check Pi built-in MCP config and runtime-only credential expansion."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PiMcpConfigTest(unittest.TestCase):
    def setUp(self):
        self.config = json.loads((ROOT / "templates/dot_pi/agent/mcp.json").read_text())

    def test_builtin_config(self):
        self.assertEqual(set(self.config), {"mcpServers"})
        self.assertEqual(set(self.config["mcpServers"]), {
            "ops-sherpa", "code-navigator-mcp", "atlassian-remote", "integrations-service",
        })
        for server in self.config["mcpServers"].values():
            self.assertTrue(server.get("enabled", True))
            self.assertEqual(server.get("exposure", "codemode"), "codemode")

    def test_code_navigator_expands_and_quotes_credentials_at_runtime(self):
        server = self.config["mcpServers"]["code-navigator-mcp"]
        with tempfile.TemporaryDirectory() as folder:
            uvx = Path(folder) / "uvx"
            uvx.write_text(f"#!{sys.executable}\nimport json, sys\nprint(json.dumps(sys.argv[1:]))\n")
            uvx.chmod(0o755)
            email = "test@example.invalid"
            key = "synthetic key $not_expanded ; not a command"
            env = {**os.environ, "PATH": folder + os.pathsep + os.environ["PATH"],
                   "ATLASSIAN_EMAIL": email, "CODE_NAVIGATOR_API_KEY": key}
            result = subprocess.run([server["command"], *server["args"]],
                                    env=env, check=True, text=True, capture_output=True)
            self.assertEqual(json.loads(result.stdout), [
                "--from", "atlassian-code-navigator-mcp", "code-navigator-mcp",
                "--email", email, "--api-key", key,
            ])
            del env["CODE_NAVIGATOR_API_KEY"]
            result = subprocess.run([server["command"], *server["args"]],
                                    env=env, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("CODE_NAVIGATOR_API_KEY is required", result.stderr)


if __name__ == "__main__":
    unittest.main()
