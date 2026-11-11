#!/usr/bin/env python3
"""Install the tmux lifecycle hook for Windows Codex from WSL."""
import json
from pathlib import Path
import shutil
import sys

EVENTS = ("PostToolUse", "SessionStart", "SessionEnd", "UserPromptSubmit", "Stop")


def install(codex_dir: Path) -> None:
    source = Path(__file__).resolve().with_name("codex.py")
    hook_dir = codex_dir / "hooks"
    hook_dir.mkdir(parents=True, exist_ok=True)
    script = hook_dir / "tmux-agent-state.py"
    shutil.copy2(source, script)
    command = "python3 " + json.dumps(str(script))

    config = codex_dir / "hooks.json"
    data = json.loads(config.read_text()) if config.exists() else {}
    if not isinstance(data, dict):
        raise ValueError("hooks.json must contain a JSON object")
    hooks = data.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise ValueError("hooks.json hooks must contain an object")
    changed = False
    for event in EVENTS:
        entries = hooks.setdefault(event, [])
        if not isinstance(entries, list):
            raise ValueError(f"hooks.{event} must be an array")
        rebuilt = []
        found = False
        for entry in entries:
            if not isinstance(entry, dict) or not isinstance(entry.get("hooks"), list):
                rebuilt.append(entry)
                continue
            owned = []
            for item in entry["hooks"]:
                old_command = item.get("command", "") if isinstance(item, dict) else ""
                # Replace only this integration's stale hook path; retain every other hook.
                if isinstance(old_command, str) and "tmux-agent-state.py" in old_command:
                    if old_command == command and not found:
                        if event == "SessionEnd" and item.get("timeout") != 3:
                            item["timeout"] = 3
                        owned.append(item)
                        found = True
                    changed = True
                else:
                    owned.append(item)
            if owned:
                rebuilt.append({**entry, "hooks": owned})
        if not found:
            rebuilt.append({"hooks": [{"type": "command", "command": command, "timeout": 3 if event == "SessionEnd" else 5}]})
            changed = True
        hooks[event] = rebuilt
    if changed or not config.exists():
        config.write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: install-windows-codex.py <WSL-path-to-Windows-.codex>")
    install(Path(sys.argv[1]))
