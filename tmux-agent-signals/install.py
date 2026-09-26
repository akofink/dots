#!/usr/bin/env python3
"""Install tmux-only provider hooks without replacing other integrations."""
import json
from pathlib import Path
import shlex
import sys


def link(source, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.is_symlink() and target.resolve() == source.resolve():
        return
    if target.exists() or target.is_symlink():
        print(f"Keeping existing provider hook: {target}", file=sys.stderr)
        return
    target.symlink_to(source)


def main():
    root = Path(__file__).resolve().parent
    home = Path.home()
    link(root / "state.py", home / ".local/bin/tmux-agent-state")
    link(root / "pi.ts", home / ".pi/agent/extensions/tmux-agent-state.ts")
    link(root / "claude.py", home / ".claude/hooks/tmux-agent-state.py")
    link(root / "codex.py", home / ".codex/tmux-agent-state.py")

    settings = home / ".claude/settings.json"
    try:
        data = json.loads(settings.read_text()) if settings.exists() else {}
        if not isinstance(data, dict):
            raise ValueError("settings is not an object")
        hooks = data.setdefault("hooks", {})
        command = "python3 " + shlex.quote(str(home / ".claude/hooks/tmux-agent-state.py"))
        changed = False
        for event in ("SessionStart", "UserPromptSubmit", "Stop", "Notification", "SessionEnd"):
            entries = hooks.setdefault(event, [])
            if any(h.get("command") == command for entry in entries for h in entry.get("hooks", []) if isinstance(h, dict)):
                continue
            entries.append({"hooks": [{"type": "command", "command": command, "timeout": 5}]})
            changed = True
        if changed:
            settings.parent.mkdir(parents=True, exist_ok=True)
            settings.write_text(json.dumps(data, indent=2) + "\n")
    except (OSError, ValueError, TypeError, AttributeError) as exc:
        print(f"Claude hook setup skipped: {exc}", file=sys.stderr)

    # Codex hooks are additive; preserve existing session hooks from other hosts.
    codex_hooks = home / ".codex/hooks.json"
    command = "python3 " + shlex.quote(str(home / ".codex/tmux-agent-state.py"))
    try:
        data = json.loads(codex_hooks.read_text()) if codex_hooks.exists() else {}
        hooks = data.setdefault("hooks", {})
        changed = False
        for event in ("SessionStart", "UserPromptSubmit", "Stop", "SessionEnd"):
            entries = hooks.setdefault(event, [])
            if any(h.get("command") == command for entry in entries for h in entry.get("hooks", []) if isinstance(h, dict)):
                continue
            entries.append({"hooks": [{"type": "command", "command": command, "timeout": 5}]})
            changed = True
        if changed:
            codex_hooks.parent.mkdir(parents=True, exist_ok=True)
            codex_hooks.write_text(json.dumps(data, indent=2) + "\n")
    except (OSError, ValueError, TypeError, AttributeError) as exc:
        print(f"Codex hook setup skipped: {exc}", file=sys.stderr)

    # Codex has one notify command. Never displace an existing owner of that slot.
    config = home / ".codex/config.toml"
    if config.exists():
        content = config.read_text()
        if any(line.strip().startswith("notify =") for line in content.splitlines()):
            print("Codex notify already configured; leave it unchanged", file=sys.stderr)
        else:
            cmd = json.dumps([sys.executable, str(home / ".codex/tmux-agent-state.py")])
            config.write_text(f"notify = {cmd}\n" + content)


if __name__ == "__main__":
    main()
