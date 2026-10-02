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
    def test_macos_notification_is_disabled_without_activating_ghostty(self):
        module = load("state")
        with patch.object(module, "subprocess") as process:
            with patch.object(module.sys, "platform", "darwin"):
                module.notify("waiting", "agent window")
        process.Popen.assert_not_called()

    def test_state_transitions_and_no_tmux_guard(self):
        module = load("state")
        calls = []
        def fake(*args):
            calls.append(args)
            if args[1] == "display-message":
                return {"#{window_id}": "@1", "#{window_name}": "task"}.get(args[-1], "")
            return ""  # no prior state
        with patch.dict(os.environ, {"TMUX_PANE": "%1"}, clear=True), \
             patch.object(module, "run", side_effect=fake), \
             patch.object(module, "notify") as notification, \
             patch.object(sys, "argv", ["state", "done"]):
            self.assertEqual(module.main(), 0)
            self.assertIn(("tmux", "set-option", "-w", "-t", "@1", "@agent_state", "done"), calls)
            notification.assert_called_once_with("done", "task")
        calls.clear()
        with patch.dict(os.environ, {}, clear=True):
            module.main()
        self.assertEqual(calls, [])

    def test_claude_event_mapping_and_subagent_guard(self):
        module = load("claude")
        from io import StringIO
        for event, expected in (("SessionStart", "idle"), ("UserPromptSubmit", "working"),
                                ("PostToolUse", "working"), ("Stop", "done"), ("Notification", "blocked"),
                                ("SessionEnd", "idle")):
            payload = {"hook_event_name": event, "notification_type": "permission_prompt"}
            with patch.dict(os.environ, {"TMUX_PANE": "%1"}, clear=True), \
                 patch.object(sys, "stdin", StringIO(json.dumps(payload))), \
                 patch.object(module.subprocess, "run") as run:
                module.main()
                self.assertEqual(run.call_args.args[0][-1], expected)
            payload["agent_id"] = "child"
            with patch.dict(os.environ, {"TMUX_PANE": "%1"}, clear=True), \
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
            claude_hooks = json.loads(first)["hooks"]
            self.assertEqual(len(claude_hooks["PostToolUse"]), 1)
            self.assertTrue((home / ".pi/agent/extensions/tmux-agent-state.ts").is_symlink())

    def test_install_merges_scoped_agent_command_rules(self):
        work_checkin = ".claude/skills/work-agent-orchestrator/scripts/checkin"
        for machine_class, count in (("work", 9), ("personal", 7)):
            with self.subTest(machine_class=machine_class), tempfile.TemporaryDirectory() as folder:
                home = Path(folder)
                settings = home / ".claude/settings.json"
                settings.parent.mkdir()
                settings.write_text(json.dumps({
                    "permissions": {"defaultMode": "auto", "allow": ["Bash(other *)"]},
                    "sandbox": {"excludedCommands": ["other *"]},
                }))
                env = {**os.environ, "HOME": folder, "MACHINE_CLASS": machine_class}
                for _ in range(2):
                    subprocess.run([sys.executable, str(ROOT / "install.py")], env=env, check=True, capture_output=True)
                data = json.loads(settings.read_text())
                allow = data["permissions"]["allow"]
                excluded = data["sandbox"]["excludedCommands"]
                self.assertEqual(data["permissions"]["defaultMode"], "auto")
                self.assertEqual(allow[0], "Bash(other *)")
                self.assertEqual(excluded[0], "other *")
                self.assertEqual(len(allow), len(set(allow)))
                self.assertEqual(len(allow), count + 1)
                self.assertEqual(excluded[1:], [rule[5:-1] for rule in allow[1:]])
                for command in (f"{folder}/.claude/skills/agent-orchestrator/scripts/checkin",
                                "~/.claude/skills/agent-orchestrator/scripts/wake-orchestrator",
                                "wake-orchestrator", "akagent", f"{folder}/.local/bin/akagent"):
                    self.assertIn(f"Bash({command} *)", allow)
                self.assertEqual(f"~/{work_checkin} *" in excluded, machine_class == "work")


if __name__ == "__main__":
    unittest.main()
