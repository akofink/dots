#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "bin/claude-work-settings.py"
FRAGMENT = ROOT / "templates/dot_claude/work-settings.json"


def run(action, settings):
    subprocess.run([sys.executable, str(SCRIPT), action, str(FRAGMENT), str(settings)],
                   check=True, capture_output=True)


class ClaudeWorkSettingsTest(unittest.TestCase):
    def test_apply_is_idempotent_and_preserves_existing_settings(self):
        with tempfile.TemporaryDirectory() as folder:
            settings = Path(folder) / "settings.json"
            settings.write_text(json.dumps({
                "theme": "light",
                "permissions": {"defaultMode": "auto", "allow": ["Bash(other *)"]},
                "sandbox": {"excludedCommands": ["other *"], "filesystem": {"allowWrite": ["~/other"]}},
            }))
            run("apply", settings)
            first = settings.read_text()
            run("apply", settings)
            self.assertEqual(first, settings.read_text())
            data = json.loads(first)
            fragment = json.loads(FRAGMENT.read_text())["sandbox"]
            self.assertEqual(data["theme"], "light")
            self.assertEqual(data["permissions"], {"defaultMode": "auto", "allow": ["Bash(other *)"]})
            self.assertEqual(data["sandbox"]["excludedCommands"], ["other *", *fragment["excludedCommands"]])
            self.assertEqual(data["sandbox"]["filesystem"]["allowWrite"],
                             ["~/other", *fragment["filesystem"]["allowWrite"]])
            self.assertIs(data["sandbox"]["network"]["allowLocalBinding"], True)
            self.assertEqual(settings.stat().st_mode & 0o777, 0o600)

    def test_remove_drops_only_managed_entries(self):
        with tempfile.TemporaryDirectory() as folder:
            settings = Path(folder) / "settings.json"
            settings.write_text(json.dumps({"theme": "light", "sandbox": {"excludedCommands": ["other *"]}}))
            run("apply", settings)
            run("remove", settings)
            self.assertEqual(json.loads(settings.read_text()),
                             {"theme": "light", "sandbox": {"excludedCommands": ["other *"]}})

    def test_remove_without_settings_creates_nothing(self):
        with tempfile.TemporaryDirectory() as folder:
            settings = Path(folder) / "settings.json"
            run("remove", settings)
            self.assertFalse(settings.exists())

    def test_invalid_shape_leaves_file_unchanged(self):
        with tempfile.TemporaryDirectory() as folder:
            settings = Path(folder) / "settings.json"
            settings.write_text('{"sandbox": []}')
            run("apply", settings)
            self.assertEqual(settings.read_text(), '{"sandbox": []}')


if __name__ == "__main__":
    unittest.main()
