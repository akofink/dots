#!/usr/bin/env python3
"""Codex hook and notify callback, preserving other integrations."""
import json
import os
from pathlib import Path
import subprocess
import sys

if __name__ == "__main__" and os.environ.get("HERDR_ENV") != "1" and os.environ.get("TMUX_PANE"):
    try:
        payload = json.loads(sys.argv[1]) if len(sys.argv) > 1 else json.load(sys.stdin)
        if payload.get("agent_id"):
            raise ValueError("subagent")
        state = {"SessionStart": "idle", "UserPromptSubmit": "working",
                 "Stop": "done", "SessionEnd": "idle"}.get(payload.get("hook_event_name"))
        if payload.get("type") == "agent-turn-complete":
            state = "done"
        if state:
            subprocess.run([str(Path.home() / ".local/bin/tmux-agent-state"), state],
                           timeout=3, stdin=subprocess.DEVNULL,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except (OSError, ValueError, TypeError, subprocess.SubprocessError):
        pass
