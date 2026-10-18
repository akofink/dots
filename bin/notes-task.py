#!/usr/bin/env python3
"""Own the notes repository's task branch and worktree lifecycle.

Agents call this instead of running git worktree or git branch in the notes repo:

  notes-task open <task-id>      create or reuse ~/dev/worktrees/notes/<task-id> on docs/<task-id>
  notes-task publish <task-id>   merge the committed task branch into canonical main and sync
  notes-task prune [--dry-run]   remove published, idle task worktrees and branches (syncdots runs this)

Prune removes a worktree or docs/* branch only when every commit is already on
origin/main (by ancestry or patch equivalence), the worktree has no tracked or
untracked changes, no akagent task in a non-terminal state owns it, no tmux pane
is inside it, and it has been idle for --idle-hours. A live task protects its
own <task-id> worktree and its newest notes resource. Ignored files (task tmp/
evidence) are moved to the canonical checkout's tmp/<worktree-name>/ first.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

HOME = Path.home()
NOTES = Path(os.environ.get("NOTES_REPO", HOME / "dev/repos/notes")).resolve()
ROOT = Path(os.environ.get("NOTES_WORKTREE_ROOT", HOME / "dev/worktrees/notes")).resolve()
AKAGENT = os.environ.get("AKAGENT_BIN", "akagent")
TMUX = os.environ.get("TMUX_BIN", "tmux")
SYNCDOTS = os.environ.get("SYNCDOTS_BIN", "syncdots")
LIVE_TASK = {"created", "active", "waiting", "blocked"}


def git(*args, cwd=NOTES, check=True):
    result = subprocess.run(["git", "-C", str(cwd), *args], text=True, capture_output=True)
    if check and result.returncode != 0:
        raise SystemExit(f"notes-task: git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def ref_exists(ref):
    return subprocess.run(["git", "-C", str(NOTES), "rev-parse", "--verify", "--quiet", ref],
                          capture_output=True).returncode == 0


def published(branch):
    """True when every branch commit is already on origin/main."""
    if not ref_exists(f"refs/heads/{branch}"):
        return True
    cherry = git("cherry", "origin/main", branch)
    return not any(line.startswith("+") for line in cherry.splitlines())


def clean(worktree):
    return git("status", "--porcelain", "--untracked-files=all", cwd=worktree) == ""


def require_task_worktree(task_id, path, branch):
    if not path.is_dir():
        raise SystemExit(f"notes-task: expected task worktree {path} does not exist; run `notes-task open {task_id}` first")
    checked_out = git("branch", "--show-current", cwd=path, check=False)
    if checked_out != branch:
        actual = checked_out or "(detached HEAD or not a worktree)"
        raise SystemExit(f"notes-task: {path} is checked out on {actual}, expected {branch}; refusing to continue")


def akagent_json(*args):
    try:
        result = subprocess.run([AKAGENT, *args, "--format", "json"], text=True, capture_output=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError:
        return None


def live_claims():
    """Worktree paths and branches owned by akagent tasks that are not terminal."""
    paths, branches = set(), set()
    listing = akagent_json("task", "list")
    if listing is None:
        raise SystemExit("notes-task: akagent task list unavailable; refusing to prune without ownership data")
    for task in listing.get("tasks", []):
        if task.get("status") not in LIVE_TASK:
            continue
        paths.add(str(ROOT / task["id"]))
        branches.add(f"docs/{task['id']}")
        detail = akagent_json("task", "inspect", task["id"]) or {}
        # Long-lived tasks accumulate resources they cannot archive while live;
        # protect only the newest (IDs sort by creation time). Older ones still
        # need the clean, published, idle, and no-pane checks before removal.
        notes = [r for r in detail.get("resources") or [] if r.get("repository") == "notes"]
        for resource in sorted(notes, key=lambda r: r.get("id", ""))[-1:]:
            if resource.get("worktree_path"):
                paths.add(str(Path(resource["worktree_path"]).resolve()))
            if resource.get("branch"):
                branches.add(resource["branch"])
    return paths, branches


def pane_paths():
    result = subprocess.run([TMUX, "list-panes", "-a", "-F", "#{pane_current_path}"],
                            text=True, capture_output=True)
    return [Path(p).resolve() for p in result.stdout.splitlines() if p] if result.returncode == 0 else []


def worktrees():
    entries, current = [], {}
    for line in git("worktree", "list", "--porcelain").splitlines() + [""]:
        if not line:
            if current:
                entries.append(current)
            current = {}
        elif " " in line:
            key, value = line.split(" ", 1)
            current[key] = value
        else:
            current[line] = True
    return entries


def last_activity(worktree):
    newest = 0.0
    for path in (worktree, Path(git("rev-parse", "--git-dir", cwd=worktree)) / "HEAD"):
        try:
            newest = max(newest, path.stat().st_mtime)
        except OSError:
            pass
    try:
        newest = max(newest, float(git("log", "-1", "--format=%ct", cwd=worktree) or 0))
    except SystemExit:
        pass
    return newest


def register(task_id, branch, path):
    detail = akagent_json("task", "inspect", task_id)
    if detail is None:
        print(f"notes-task: akagent task {task_id} not found; resource not registered", file=sys.stderr)
        return
    if any(r.get("worktree_path") == str(path) for r in detail.get("resources") or []):
        return
    subprocess.run([AKAGENT, "task", "resource", "create", task_id, "--repository", "notes",
                    "--branch", branch, "--worktree", str(path)], capture_output=True, text=True)


def cmd_open(args):
    branch, path = f"docs/{args.task_id}", ROOT / args.task_id
    git("fetch", "--quiet", "origin")
    if path.exists():
        require_task_worktree(args.task_id, path, branch)
        print(path)
        return
    ROOT.mkdir(parents=True, exist_ok=True)
    if ref_exists(f"refs/heads/{branch}") and published(branch):
        git("branch", "-f", branch, "origin/main")  # fully published: restart from main
    if ref_exists(f"refs/heads/{branch}"):
        git("worktree", "add", str(path), branch)
    else:
        git("worktree", "add", "--no-track", "-b", branch, str(path), "origin/main")
    register(args.task_id, branch, path)
    print(path)


def cmd_publish(args):
    branch, path = f"docs/{args.task_id}", ROOT / args.task_id
    require_task_worktree(args.task_id, path, branch)
    if not ref_exists(f"refs/heads/{branch}"):
        raise SystemExit(f"notes-task: expected task branch {branch} does not exist; refusing to publish")
    if not clean(path):
        raise SystemExit(f"notes-task: {path} has uncommitted changes; commit owned paths first")
    if git("symbolic-ref", "--short", "HEAD") != "main":
        raise SystemExit("notes-task: canonical notes checkout is not on main; leave it for the owner")
    if git("status", "--porcelain", "--untracked-files=no"):
        raise SystemExit("notes-task: canonical notes main has tracked changes; leave them and retry later")
    for marker in ("MERGE_HEAD", "rebase-merge", "rebase-apply"):
        if Path(git("rev-parse", "--path-format=absolute", "--git-path", marker)).exists():
            raise SystemExit(f"notes-task: canonical notes has {marker} in progress; leave it for the owner")
    if published(branch):
        print(f"notes-task: {branch} is already published")
    else:
        merged = subprocess.run(["git", "-C", str(NOTES), "merge", "--no-ff", "--no-edit",
                                 "-m", f"Merge {branch}", branch], text=True, capture_output=True)
        if merged.returncode != 0:  # never leave canonical main mid-merge
            subprocess.run(["git", "-C", str(NOTES), "merge", "--abort"], capture_output=True)
            raise SystemExit(f"notes-task: {branch} conflicts with main; canonical main was restored. "
                             f"In the task worktree run `git merge origin/main`, resolve, commit, and publish again.")
    result = subprocess.run([SYNCDOTS, "--quiet"])
    if result.returncode != 0:
        raise SystemExit("notes-task: syncdots failed; canonical main keeps the local merge for retry")
    if not published(branch):
        raise SystemExit(f"notes-task: {branch} is still not on origin/main after sync")
    print(f"notes-task: published {branch} at {git('rev-parse', '--short', 'origin/main')}")


def cmd_prune(args):
    git("fetch", "--quiet", "origin")
    claimed_paths, claimed_branches = live_claims()
    panes = pane_paths()
    cutoff = time.time() - args.idle_hours * 3600
    checked_out = set()
    for entry in worktrees():
        path = Path(entry["worktree"]).resolve()
        branch = entry.get("branch", "").removeprefix("refs/heads/")
        if branch:
            checked_out.add(branch)
        if path.parent != ROOT or not branch.startswith("docs/"):
            continue
        reason = None
        if str(path) in claimed_paths or branch in claimed_branches:
            reason = "owned by a live task"
        elif any(p == path or path in p.parents for p in panes):
            reason = "a tmux pane is inside it"
        elif not clean(path):
            reason = "has uncommitted changes"
        elif not published(branch):
            reason = "has unpublished commits"
        elif last_activity(path) > cutoff:
            reason = "recently active"
        if reason:
            if args.verbose:
                print(f"keep {path.name}: {reason}")
            continue
        ignored = git("ls-files", "--others", "--ignored", "--exclude-standard", "--directory", cwd=path)
        print(f"{'would remove' if args.dry_run else 'remove'} worktree {path.name} ({branch})")
        if args.dry_run:
            continue
        if ignored:
            dest = NOTES / "tmp" / path.name
            for rel in ignored.splitlines():
                src = path / rel.rstrip("/")
                target = dest / rel.rstrip("/")
                target.parent.mkdir(parents=True, exist_ok=True)
                if src.exists() and not target.exists():
                    shutil.move(str(src), str(target))
        git("worktree", "remove", str(path))
        git("branch", "-D", branch)
        checked_out.discard(branch)
    for branch in git("for-each-ref", "--format=%(refname:short)", "refs/heads/docs/").splitlines():
        if branch in checked_out or branch in claimed_branches or not published(branch):
            continue
        tip_time = float(git("log", "-1", "--format=%ct", branch) or 0)
        if tip_time > cutoff:
            continue
        print(f"{'would delete' if args.dry_run else 'delete'} branch {branch}")
        if not args.dry_run:
            git("branch", "-D", branch)
    git("worktree", "prune")


def main():
    parser = argparse.ArgumentParser(prog="notes-task", description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("open", "publish"):
        p = sub.add_parser(name)
        p.add_argument("task_id")
    p = sub.add_parser("prune")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--verbose", action="store_true")
    p.add_argument("--idle-hours", type=float, default=2.0)
    args = parser.parse_args()
    {"open": cmd_open, "publish": cmd_publish, "prune": cmd_prune}[args.command](args)


if __name__ == "__main__":
    main()
