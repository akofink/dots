#!/usr/bin/env python3
"""Render open personal machine-wide actions without changing their source."""

from __future__ import annotations

import os
from pathlib import Path
import socket
import sys


def action_file() -> Path | None:
    configured = os.environ.get("PERSONAL_ACTION_LIST_FILE")
    if configured:
        return Path(configured).expanduser()
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))).expanduser()
    pointer = Path(os.environ.get("DOTS_PERSONAL_ACTION_POINTER", str(config_home / "dots" / "personal-action-list-path"))).expanduser()
    try:
        target = pointer.read_text(encoding="utf-8").strip()
    except OSError:
        return None
    return Path(target).expanduser() if target else None


def selected_host() -> str:
    return (os.environ.get("PERSONAL_ACTION_HOST") or socket.gethostname()).split(".", 1)[0]


def read_actions(path: Path, host: str) -> list[tuple[str, str]]:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []

    actions: list[tuple[str, str]] = []
    section = None
    current_host = None
    in_machine_section = False
    for line in lines:
        if line.startswith("## "):
            in_machine_section = line == "## Machine-wide actions (by host)"
            section = None
            current_host = None
            continue
        if not in_machine_section:
            continue
        if line.startswith("### "):
            section = line[4:].strip()
            current_host = None
        elif line.startswith("#### "):
            current_host = line[5:].strip()
        elif (
            section in {"Operator actions", "Agent follow-ups"}
            and current_host in {host, "any host"}
            and line.startswith("- [ ] ")
        ):
            actions.append((section, line[6:].strip()))
    return actions


def main() -> int:
    if os.environ.get("MACHINE_CLASS", "personal").strip().lower() == "work":
        return 0
    path = action_file()
    if path is None:
        return 0
    actions = read_actions(path, selected_host())
    if actions:
        print("Machine-wide personal actions:")
        for section, action in actions:
            print(f"- {section}: {action}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
