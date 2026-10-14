#!/usr/bin/env python3
"""Merge or remove the managed work-machine Claude Code settings fragment.

Managed policy on work machines ignores user permission rules, so the fragment
only widens sandbox settings that user scope may still extend. Arrays are
unioned in place; scalars are set. Removal drops only entries and scalars that
still match the fragment, preserving anything the user added.
"""
import json
from pathlib import Path
import sys


def merge(target, fragment):
    changed = False
    for key, value in fragment.items():
        if isinstance(value, dict):
            child = target.setdefault(key, {})
            if not isinstance(child, dict):
                raise ValueError(f"{key} is not an object")
            changed |= merge(child, value)
        elif isinstance(value, list):
            items = target.setdefault(key, [])
            if not isinstance(items, list):
                raise ValueError(f"{key} is not an array")
            for item in value:
                if item not in items:
                    items.append(item)
                    changed = True
        elif target.get(key) != value:
            target[key] = value
            changed = True
    return changed


def remove(target, fragment):
    changed = False
    for key, value in fragment.items():
        if key not in target:
            continue
        current = target[key]
        if isinstance(value, dict) and isinstance(current, dict):
            changed |= remove(current, value)
            if not current:
                del target[key]
        elif isinstance(value, list) and isinstance(current, list):
            kept = [item for item in current if item not in value]
            if kept != current:
                changed = True
                if kept:
                    target[key] = kept
                else:
                    del target[key]
        elif current == value:
            del target[key]
            changed = True
    return changed


def main():
    if len(sys.argv) != 4 or sys.argv[1] not in ("apply", "remove"):
        sys.exit("usage: claude-work-settings.py apply|remove <fragment.json> <settings.json>")
    action, fragment_path, settings_path = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
    fragment = json.loads(fragment_path.read_text())
    try:
        data = json.loads(settings_path.read_text()) if settings_path.exists() else {}
        if not isinstance(data, dict):
            raise ValueError("settings is not an object")
        changed = (merge if action == "apply" else remove)(data, fragment)
    except (OSError, ValueError) as exc:
        print(f"Claude work settings skipped: {exc}", file=sys.stderr)
        return
    if changed:
        settings_path.parent.mkdir(parents=True, exist_ok=True)
        tmp = settings_path.with_name(settings_path.name + ".tmp")
        tmp.write_text(json.dumps(data, indent=2) + "\n")
        tmp.chmod(0o600)
        tmp.replace(settings_path)


if __name__ == "__main__":
    main()
