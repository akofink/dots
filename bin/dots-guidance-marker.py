#!/usr/bin/env python3
"""Write the orchestrator-consumed marker when synced agent guidance changes."""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 5:
        print(f"usage: {sys.argv[0]} NOTES_REPO OLD_COMMIT NEW_COMMIT STATE_DIR", file=sys.stderr)
        return 2
    # Keep argument handling explicit; paths may contain spaces.
    notes_repo = Path(sys.argv[1])
    old_commit, new_commit = sys.argv[2], sys.argv[3]
    state_dir = Path(sys.argv[4])
    changed = subprocess.run(
        ["git", "-C", str(notes_repo), "diff", "--quiet", old_commit, new_commit, "--", "agents/", "skills/"],
        check=False,
    ).returncode
    if changed == 0:
        return 0
    if changed != 1:
        return 1
    state_dir.mkdir(parents=True, exist_ok=True)
    marker = state_dir / "guidance-changed"
    temporary = marker.with_name(f".{marker.name}.{os.getpid()}")
    temporary.write_text(f"commit={new_commit}\n", encoding="utf-8")
    temporary.replace(marker)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
