#!/usr/bin/env python3
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1] / "tmux-agent-signals"


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class SignalsTest(unittest.TestCase):
    def test_state_transitions_and_herdr_guard(self):
        module = load("state")
        calls = []
        def fake(*args):
            calls.append(args)
            if args[1] == "display-message":
                return "@1" if args[-1] == "#{window_id}" else "task"
            return ""  # no prior state
        with patch.dict(os.environ, {"TMUX_PANE": "%1", "HERDR_ENV": "0"}), \
             patch.object(module, "run", side_effect=fake), \
             patch.object(module, "notify") as notification, \
             patch.object(sys, "argv", ["state", "done"]):
            self.assertEqual(module.main(), 0)
            self.assertIn(("tmux", "set-option", "-w", "-t", "@1", "@agent_state", "done"), calls)
            notification.assert_called_once_with("done", "task")
            calls.clear()
            os.environ["HERDR_ENV"] = "1"
            module.main()
            self.assertEqual(calls, [])

    def test_claude_event_mapping_and_subagent_guard(self):
        module = load("claude")
        from io import StringIO
        for event, expected in (("SessionStart", "idle"), ("UserPromptSubmit", "working"),
                                ("Stop", "done"), ("Notification", "blocked"),
                                ("SessionEnd", "idle")):
            payload = {"hook_event_name": event, "notification_type": "permission_prompt"}
            with patch.dict(os.environ, {"TMUX_PANE": "%1", "HERDR_ENV": "0"}), \
                 patch.object(sys, "stdin", StringIO(json.dumps(payload))), \
                 patch.object(module.subprocess, "run") as run:
                module.main()
                self.assertEqual(run.call_args.args[0][-1], expected)
            payload["agent_id"] = "child"
            with patch.dict(os.environ, {"TMUX_PANE": "%1", "HERDR_ENV": "0"}), \
                 patch.object(sys, "stdin", StringIO(json.dumps(payload))), \
                 patch.object(module.subprocess, "run") as run:
                module.main()
                run.assert_not_called()

    def test_install_preserves_existing_hooks_and_codex_notify(self):
        with tempfile.TemporaryDirectory() as folder:
            home = Path(folder)
            (home / ".claude").mkdir()
            (home / ".codex").mkdir()
            settings = home / ".claude/settings.json"
            settings.write_text(json.dumps({"hooks": {"Stop": [{"hooks": [{"type": "command", "command": "other"}]}]}}))
            config = home / ".codex/config.toml"
            config.write_text('notify = ["other"]\n')
            env = {**os.environ, "HOME": folder}
            subprocess.run([sys.executable, str(ROOT / "install.py")], env=env, check=True, capture_output=True)
            first = settings.read_text()
            subprocess.run([sys.executable, str(ROOT / "install.py")], env=env, check=True, capture_output=True)
            self.assertEqual(first, settings.read_text())
            self.assertIn('"other"', first)
            self.assertEqual(config.read_text(), 'notify = ["other"]\n')
            codex_hooks = json.loads((home / ".codex/hooks.json").read_text())["hooks"]
            self.assertEqual(len(codex_hooks["Stop"]), 1)
            self.assertTrue((home / ".pi/agent/extensions/tmux-agent-state.ts").is_symlink())


if __name__ == "__main__":
    unittest.main()
