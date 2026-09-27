#!/usr/bin/env python3
import importlib.util
import json
import os
from pathlib import Path
import shlex
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
    def test_macos_notification_command_uses_stable_tmux_targets(self):
        module = load("state")
        command = module.macos_notification_command(
            "done", "agent window", "/Users/me/.local/bin/tmux", "/tmp/tmux.sock", "$0", "%7")
        self.assertEqual(command[:6], ["terminal-notifier", "-title", "agent window", "-message", "done", "-activate"])
        self.assertEqual(command[6:8], ["com.mitchellh.ghostty", "-execute"])
        self.assertIn("/Users/me/.local/bin/tmux", command[8])
        self.assertIn("-S /tmp/tmux.sock", command[8])
        self.assertIn("list-clients", command[8])
        self.assertIn("#{client_activity}", command[8])
        self.assertIn("switch-client -c", command[8])
        self.assertIn("select-pane -t \"$pane\"", command[8])
        self.assertIn("/usr/bin/open -na /Applications/Ghostty.app", command[8])
        self.assertIn("attach-session", command[8])
        self.assertIn("select-pane -t %7", command[8])

    def test_macos_notification_detached_branch_opens_ghostty_to_stable_pane(self):
        module = load("state")
        tmux = str(Path.home() / ".local/bin/tmux")
        with tempfile.TemporaryDirectory() as folder:
            socket = str(Path(folder) / "tmux.sock")
            log = str(Path(folder) / "open-args.log")
            open_stub = Path(folder) / "open"
            open_stub.write_text("#!/bin/sh\nprintf '%s\\n' \"$@\" > " + shlex.quote(log) + "\n")
            open_stub.chmod(0o755)
            subprocess.run([tmux, "-S", socket, "new-session", "-d", "-s", "click-test"], check=True)
            try:
                session = subprocess.run([tmux, "-S", socket, "display-message", "-p", "-t", "click-test", "#{session_id}"], check=True, capture_output=True, text=True).stdout.strip()
                pane = subprocess.run([tmux, "-S", socket, "list-panes", "-t", session, "-F", "#{pane_id}"], check=True, capture_output=True, text=True).stdout.strip()
                command = module.macos_notification_command("done", "test", tmux, socket, session, pane, str(open_stub))[-1]
                subprocess.run(["/usr/bin/env", "-i", "PATH=/usr/bin:/bin:/usr/sbin:/sbin", "/bin/sh", "-c", command], check=True)
                args = Path(log).read_text()
                self.assertIn("/Applications/Ghostty.app", args)
                self.assertIn(session, args)
                self.assertIn(pane, args)
                self.assertIn("attach-session", args)
            finally:
                subprocess.run([tmux, "-S", socket, "kill-server"], check=False, capture_output=True)

    def test_state_transitions_and_no_tmux_guard(self):
        module = load("state")
        calls = []
        def fake(*args):
            calls.append(args)
            if args[1] == "display-message":
                return {"#{window_id}": "@1", "#{window_name}": "task",
                        "#{socket_path}": "/tmp/tmux.sock", "#{session_id}": "$1",
                        "#{pane_id}": "%1"}.get(args[-1], "")
            return ""  # no prior state
        with patch.dict(os.environ, {"TMUX_PANE": "%1"}, clear=True), \
             patch.object(module, "run", side_effect=fake), \
             patch.object(module, "notify") as notification, \
             patch.object(module, "tmux_server_binary", return_value="/Users/me/.local/bin/tmux"), \
             patch.object(sys, "argv", ["state", "done"]):
            self.assertEqual(module.main(), 0)
            self.assertIn(("tmux", "set-option", "-w", "-t", "@1", "@agent_state", "done"), calls)
            notification.assert_called_once_with(
                "done", "task", "/Users/me/.local/bin/tmux", "/tmp/tmux.sock", "$1", "%1")
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


if __name__ == "__main__":
    unittest.main()
