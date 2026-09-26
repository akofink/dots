#!/usr/bin/env python3
"""Claude Code hook adapter; never block Claude on reporting failures."""
import json
import os
from pathlib import Path
import subprocess
import sys

EVENTS = {
    "SessionStart": "idle",
    "UserPromptSubmit": "working",
    "Stop": "done",
    "SessionEnd": "idle",
}


def main():
    if os.environ.get("HERDR_ENV") == "1" or not os.environ.get("TMUX_PANE"):
        return
    try:
        data = json.load(sys.stdin)
        if not isinstance(data, dict) or data.get("agent_id") or os.environ.get("CURSOR_VERSION"):
            return
        event = data.get("hook_event_name")
        state = EVENTS.get(event)
        if event == "Notification":
            if data.get("notification_type") == "permission_prompt":
                state = "blocked"
            elif data.get("notification_type") == "idle_prompt":
                state = "waiting"
        if state:
            subprocess.run([str(Path.home() / ".local/bin/tmux-agent-state"), state],
                           stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=3)
    except (OSError, ValueError, subprocess.SubprocessError):
        pass


if __name__ == "__main__":
    main()
