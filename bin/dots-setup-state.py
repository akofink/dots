#!/usr/bin/env python3
"""Deterministic content fingerprints for curated dots setup modules."""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import sys

MODULES = ("http", "aws", "vim", "tmux", "zsh", "llm", "opencode", "rbenv", "go", "tmuxinator", "glow", "ghostty", "akagent")
DEPENDENCIES = {
    "zsh": ("bin/dots-warmup-report.sh",),
    "tmuxinator": ("setup/rbenv.sh",),
    "glow": ("setup/go.sh",),
    "akagent": ("setup/go.sh",),
    "llm": ("setup/opencode.sh",),
}


def paths_for(module: str, dots: Path, notes: Path) -> list[tuple[str, Path]]:
    if module not in MODULES:
        raise ValueError(f"unknown setup module: {module}")
    paths: list[tuple[str, Path]] = []
    rels = (
        f"setup/{module}.sh",
        "setup.sh",
        "setup/util.sh",
        "setup/repos.sh",
        "setup/env.sh",
        "bin/dots-setup-state.py",
        *DEPENDENCIES.get(module, ()),
    )
    for rel in rels:
        paths.append((f"dots/{rel}", dots / rel))
    # Templates are consumed indirectly by setup modules and helper scripts.
    template_root = dots / "templates"
    if template_root.exists():
        for path in sorted(p for p in template_root.rglob("*") if p.is_file()):
            paths.append((f"dots/{path.relative_to(dots).as_posix()}", path))
    else:
        paths.append(("dots/templates/", template_root))
    if module == "llm":
        for root_name in ("agents", "skills"):
            root = notes / root_name
            if root.exists():
                for path in sorted(p for p in root.rglob("*") if p.is_file()):
                    paths.append((f"notes/{path.relative_to(notes).as_posix()}", path))
            else:
                paths.append((f"notes/{root_name}/", root))
    return paths


def fingerprint(module: str, dots: Path, notes: Path) -> str:
    digest = hashlib.sha256()
    for name, path in sorted(paths_for(module, dots, notes), key=lambda item: item[0]):
        digest.update(name.encode("utf-8"))
        digest.update(b"\0")
        if path.is_file():
            digest.update(b"file\0")
            with path.open("rb") as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b""):
                    digest.update(block)
        else:
            digest.update(b"missing\0")
        digest.update(b"\0")
    digest.update(os.environ.get("MACHINE_CLASS", "personal").encode())
    digest.update(b"\0")
    digest.update(os.environ.get("PLATFORM", "").encode())
    return digest.hexdigest()


def main() -> int:
    if len(sys.argv) != 4 or sys.argv[1] not in MODULES:
        print(f"usage: {sys.argv[0]} <module> <dots-repo> <notes-repo>", file=sys.stderr)
        return 2
    print(fingerprint(sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
