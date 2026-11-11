#!/usr/bin/env python3
"""Own the notes repository's task branch and worktree lifecycle.

Agents call this instead of running git worktree or git branch in the notes repo:

  notes-task open <task-id>      create or reuse ~/dev/worktrees/notes/<task-id> on docs/<task-id>
  notes-task publish <task-id>   merge the committed task branch into its owning main and sync
  notes-task prune [--dry-run]   remove published, idle task worktrees and branches (syncdots runs this)
  notes-task park <name> --reason <text>
                                 retire an idle, unowned, unpublished worktree; keep its branch and pin
                                 refs/notes-task/parked/<name> (--checkpoint-dirty commits edits first)

New tasks use the separate NOTES_AGENT_REPO clone by default. Existing task worktrees and
branches in NOTES_REPO remain attached to that legacy checkout until their owners finish.
The isolated lane publishes without refreshing links into the operator checkout.

Prune removes a worktree or docs/* branch only when every commit is already on
origin/main (by ancestry or patch equivalence), the worktree has no tracked or
untracked changes, no akagent task in a non-terminal state owns it, no tmux pane
is inside it, and it has been idle for --idle-hours. A live task protects its
own <task-id> worktree and its newest notes resource. Ignored files (task tmp/
evidence) are moved to the canonical checkout's tmp/<worktree-name>/ first.
"""
import argparse
try:
    import fcntl
except ImportError:  # Windows uses the standard-library byte-range lock.
    fcntl = None
    import msvcrt
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

HOME = Path.home()
NOTES = Path(os.environ.get("NOTES_REPO", HOME / "dev/repos/notes")).resolve()
AGENT_NOTES = Path(os.environ.get("NOTES_AGENT_REPO", HOME / "dev/repos/notes-agent")).resolve()
ROOT = Path(os.environ.get("NOTES_WORKTREE_ROOT", HOME / "dev/worktrees/notes")).resolve()
PUBLISH_LOCK = Path(os.environ.get("XDG_STATE_HOME", HOME / ".local/state")) / "notes-task" / "publish.lock"
AKAGENT = os.environ.get("AKAGENT_BIN", "akagent")
TMUX = os.environ.get("TMUX_BIN", "tmux")
SYNCDOTS = os.environ.get("SYNCDOTS_BIN", "syncdots")
LIVE_TASK = {"created", "active", "waiting", "blocked"}


def git(*args, cwd=None, check=True):
    cwd = NOTES if cwd is None else cwd
    result = subprocess.run(["git", "-C", str(cwd), *args], text=True, capture_output=True)
    if check and result.returncode != 0:
        raise SystemExit(f"notes-task: git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def ref_exists(ref):
    return subprocess.run(["git", "-C", str(NOTES), "rev-parse", "--verify", "--quiet", ref],
                          capture_output=True).returncode == 0


def common_dir(repo):
    return Path(git("rev-parse", "--path-format=absolute", "--git-common-dir", cwd=repo)).resolve()


def repository_for_worktree(path):
    try:
        task_common = common_dir(path)
    except SystemExit:
        raise SystemExit(f"notes-task: {path} is not a recognized notes worktree; refusing to continue")
    candidates = {NOTES, AGENT_NOTES}
    for repo in candidates:
        if repo.is_dir():
            try:
                if common_dir(repo) == task_common:
                    return repo
            except SystemExit:
                continue
    raise SystemExit(f"notes-task: {path} belongs to an unconfigured notes clone; refusing to rebind it")


def ensure_agent_repo():
    if AGENT_NOTES == NOTES:
        raise SystemExit("notes-task: NOTES_AGENT_REPO must be separate from NOTES_REPO")
    if AGENT_NOTES.exists():
        if not (AGENT_NOTES / ".git").exists():
            raise SystemExit(f"notes-task: agent notes path exists but is not a Git checkout: {AGENT_NOTES}")
        return AGENT_NOTES

    remote = os.environ.get("NOTES_REPO_URL")
    if not remote:
        remote = git("remote", "get-url", "origin", cwd=NOTES)
    AGENT_NOTES.parent.mkdir(parents=True, exist_ok=True)
    cloned = subprocess.run(["git", "clone", "--", remote, str(AGENT_NOTES)], text=True, capture_output=True)
    if cloned.returncode != 0:
        raise SystemExit(f"notes-task: unable to initialize agent notes clone: {cloned.stderr.strip()}")
    return AGENT_NOTES


def initialize_agent_checkout():
    """Safely recover an empty agent clone whose symbolic HEAD has no commit."""
    if subprocess.run(["git", "-C", str(AGENT_NOTES), "rev-parse", "--verify", "--quiet", "HEAD^{commit}"],
                      capture_output=True).returncode == 0:
        return

    remote_head = git("symbolic-ref", "--quiet", "refs/remotes/origin/HEAD", cwd=AGENT_NOTES, check=False)
    candidates = [remote_head, "refs/remotes/origin/main"]
    target = next((ref for ref in candidates if ref and ref.startswith("refs/remotes/origin/") and
                   subprocess.run(["git", "-C", str(AGENT_NOTES), "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}"],
                                  capture_output=True).returncode == 0), None)
    if target is None:
        raise SystemExit("notes-task: agent clone HEAD is unborn and neither origin/HEAD nor origin/main resolves to a commit; "
                         "preserving clone for inspection")

    branch = target.removeprefix("refs/remotes/origin/")
    if subprocess.run(["git", "-C", str(AGENT_NOTES), "check-ref-format", "--branch", branch],
                      capture_output=True).returncode != 0:
        raise SystemExit(f"notes-task: agent clone remote default {target} is not a valid branch; preserving clone")
    local_branches = git("for-each-ref", "--format=%(refname)", "refs/heads/", cwd=AGENT_NOTES)
    if local_branches:
        raise SystemExit(f"notes-task: agent clone HEAD is unborn but local branches exist ({local_branches}); "
                         "preserving clone for inspection")
    listed = git("worktree", "list", "--porcelain", cwd=AGENT_NOTES)
    worktree_paths = [line.removeprefix("worktree ") for line in listed.splitlines() if line.startswith("worktree ")]
    if len(worktree_paths) != 1 or Path(worktree_paths[0]).resolve() != AGENT_NOTES:
        raise SystemExit("notes-task: agent clone HEAD is unborn and other worktrees exist; preserving clone for inspection")
    dirty = git("status", "--porcelain", "--untracked-files=all", cwd=AGENT_NOTES)
    if dirty:
        raise SystemExit(f"notes-task: agent clone HEAD is unborn and checkout/index state is not clean ({dirty}); "
                         "preserving clone for inspection")
    unexpected = [path.name for path in AGENT_NOTES.iterdir() if path.name != ".git"]
    if unexpected:
        raise SystemExit(f"notes-task: agent clone HEAD is unborn but checkout files exist ({', '.join(unexpected)}); "
                         "preserving clone for inspection")

    result = subprocess.run(["git", "-C", str(AGENT_NOTES), "checkout", "-b", branch, target],
                            text=True, capture_output=True)
    if result.returncode != 0:
        raise SystemExit(f"notes-task: unable to initialize empty agent clone on {branch}: {result.stderr.strip()}; "
                         "preserving clone for inspection")


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


def publisher_lock():
    PUBLISH_LOCK.parent.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(PUBLISH_LOCK, os.O_CREAT | os.O_RDWR, 0o600)
    try:
        if fcntl is not None:
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        else:
            if os.fstat(descriptor).st_size == 0:
                os.write(descriptor, b"\0")
            os.lseek(descriptor, 0, os.SEEK_SET)
            msvcrt.locking(descriptor, msvcrt.LK_NBLCK, 1)
    except OSError:
        os.close(descriptor)
        raise SystemExit("notes-task: another notes publication is running; preserve state and retry after it finishes")
    return descriptor


def release_publisher_lock(descriptor):
    if fcntl is not None:
        fcntl.flock(descriptor, fcntl.LOCK_UN)
    else:
        os.lseek(descriptor, 0, os.SEEK_SET)
        msvcrt.locking(descriptor, msvcrt.LK_UNLCK, 1)
    os.close(descriptor)


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


def live_claims(*, strict=False):
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
        detail = akagent_json("task", "inspect", task["id"])
        if detail is None and strict:
            raise SystemExit("notes-task: task ownership inspection unavailable")
        detail = detail or {}
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
                    "--branch", branch, "--worktree", str(path),
                    "--metadata", "delivery_contract=local_publication"], capture_output=True, text=True)


def cmd_open(args):
    global NOTES
    branch, path = f"docs/{args.task_id}", ROOT / args.task_id
    if path.exists():
        NOTES = repository_for_worktree(path)
        require_task_worktree(args.task_id, path, branch)
    elif subprocess.run(["git", "-C", str(NOTES), "show-ref", "--verify", "--quiet",
                         f"refs/heads/{branch}"]).returncode != 0:
        NOTES = ensure_agent_repo()

    git("fetch", "--quiet", "origin")
    if NOTES == AGENT_NOTES:
        initialize_agent_checkout()
    if path.exists():
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


def cmd_publish_locked(branch, path):
    if not ref_exists(f"refs/heads/{branch}"):
        raise SystemExit(f"notes-task: expected task branch {branch} does not exist; refusing to publish")
    if not clean(path):
        raise SystemExit(f"notes-task: {path} has uncommitted changes; commit owned paths first")
    if git("symbolic-ref", "--short", "HEAD") != "main":
        raise SystemExit("notes-task: integration checkout is not on main; leave it for the owner")
    status_args = ["status", "--porcelain", "--untracked-files=all"] if NOTES == AGENT_NOTES else [
        "status", "--porcelain", "--untracked-files=no"]
    if git(*status_args):
        scope = "agent integration" if NOTES == AGENT_NOTES else "canonical notes"
        raise SystemExit(f"notes-task: {scope} main has local changes; leave them and retry later")
    for marker in ("MERGE_HEAD", "rebase-merge", "rebase-apply"):
        if Path(git("rev-parse", "--path-format=absolute", "--git-path", marker)).exists():
            raise SystemExit(f"notes-task: integration checkout has {marker} in progress; leave it for the owner")
    if published(branch):
        print(f"notes-task: {branch} is already published")
    else:
        merged = subprocess.run(["git", "-C", str(NOTES), "merge", "--no-ff", "--no-edit",
                                 "-m", f"Merge {branch}", branch], text=True, capture_output=True)
        if merged.returncode != 0:
            conflicts = git("diff", "--name-only", "--diff-filter=U", check=False).splitlines()
            aborted = subprocess.run(["git", "-C", str(NOTES), "merge", "--abort"], text=True, capture_output=True)
            if aborted.returncode != 0:
                raise SystemExit(f"notes-task: {branch} conflicts and integration abort failed; preserve and inspect "
                                 f"the checkout before retrying: {aborted.stderr.strip()}")
            if any(path in {"AGENTS.md", "agents"} or path.startswith("agents/") for path in conflicts):
                raise SystemExit(f"notes-task: {branch} conflicts in shared agent guidance; integration was aborted. "
                                 "Preserve both sides and report the conflict to the primary; do not resolve by preference.")
            raise SystemExit(f"notes-task: {branch} conflicts with main; integration was aborted. "
                             f"In the task worktree run `git merge origin/main`, resolve, and publish again.")

    sync_env = None
    if NOTES == AGENT_NOTES:
        sync_env = {**os.environ, "NOTES_REPO": str(NOTES), "DOTS_SYNC_NOTES_ONLY": "1"}
    result = subprocess.run([SYNCDOTS, "--quiet"], env=sync_env)
    if result.returncode != 0:
        raise SystemExit("notes-task: syncdots failed; integration checkout keeps the local merge for retry")
    if not published(branch):
        raise SystemExit(f"notes-task: {branch} is still not on origin/main after sync")
    print(f"notes-task: published {branch} at {git('rev-parse', '--short', 'origin/main')}")


def cmd_publish(args):
    global NOTES
    branch, path = f"docs/{args.task_id}", ROOT / args.task_id
    require_task_worktree(args.task_id, path, branch)
    NOTES = repository_for_worktree(path)
    descriptor = publisher_lock()
    try:
        require_task_worktree(args.task_id, path, branch)
        cmd_publish_locked(branch, path)
    finally:
        release_publisher_lock(descriptor)


def move_ignored(path):
    """Move ignored task evidence to the clone's tmp/<worktree-name>/; return the destination or None."""
    ignored = git("ls-files", "--others", "--ignored", "--exclude-standard", "--directory", cwd=path)
    if not ignored:
        return None
    dest = NOTES / "tmp" / path.name
    for rel in ignored.splitlines():
        src = path / rel.rstrip("/")
        target = dest / rel.rstrip("/")
        target.parent.mkdir(parents=True, exist_ok=True)
        if src.exists() and not target.exists():
            shutil.move(str(src), str(target))
    return dest


OS_CRUFT = {".DS_Store"}


def blob_id(path):
    data = os.readlink(path).encode() if path.is_symlink() else path.read_bytes()
    return hashlib.sha1(b"blob %d\0" % len(data) + data).hexdigest()


def remove_worktree(path, tip):
    """`git worktree remove` without force, finishing a partial removal only when safe.

    macOS can recreate .DS_Store while Git deletes the checkout; Git then fails after
    dropping the worktree's admin entry and leaves a partial directory. Finish that
    removal only when the worktree is no longer registered and every leftover is OS
    cruft or byte-identical to the committed tip; otherwise preserve it and stop.
    """
    result = subprocess.run(["git", "-C", str(NOTES), "worktree", "remove", str(path)],
                            text=True, capture_output=True)
    if result.returncode == 0 and not path.exists():
        return
    if any(Path(e["worktree"]).resolve() == path.resolve() for e in worktrees()):
        raise SystemExit(f"notes-task: git worktree remove {path} failed and it is still registered; "
                         f"preserving it: {result.stderr.strip()}")
    committed = {}
    for line in git("ls-tree", "-r", "--full-tree", tip).splitlines():
        meta, rel = line.split("\t", 1)
        committed[rel] = meta.split()[2]
    for _ in range(5):
        if not path.exists():
            return
        for file in [p for p in path.rglob("*") if p.is_file() or p.is_symlink()]:
            rel = file.relative_to(path).as_posix()
            if file.name in OS_CRUFT or rel == ".git":
                continue
            if committed.get(rel) != blob_id(file):
                raise SystemExit(f"notes-task: partial removal left {file} that differs from {tip}; "
                                 "preserving the directory for inspection")
        shutil.rmtree(path, ignore_errors=True)
    raise SystemExit(f"notes-task: unable to finish removing {path}; leftovers match {tip} and are preserved")


def cmd_park(args):
    """Retire an idle, unowned worktree that prune keeps because it is unpublished or dirty.

    The branch and its history stay; the tip is also pinned under
    refs/notes-task/parked/<name> with the reason in the reflog. Only the
    worktree checkout is removed (never forced). `notes-task open` on the
    branch's task ID resumes it.
    """
    global NOTES
    reason = " ".join(args.reason.split())
    if not reason:
        raise SystemExit("notes-task: park requires a non-empty --reason")
    path = ROOT / args.name
    if path.parent != ROOT or not path.is_dir():
        raise SystemExit(f"notes-task: {path} is not a notes task worktree")
    NOTES = repository_for_worktree(path)
    entry = next((e for e in worktrees() if Path(e["worktree"]).resolve() == path.resolve()), None)
    branch = (entry or {}).get("branch", "").removeprefix("refs/heads/")
    if not branch.startswith("docs/"):
        raise SystemExit(f"notes-task: {path} is not on a docs/* branch; refusing to park")
    descriptor = publisher_lock()
    try:
        claimed_paths, claimed_branches = live_claims(strict=True)
        if str(path.resolve()) in claimed_paths or branch in claimed_branches:
            raise SystemExit(f"notes-task: {args.name} is owned by a live task; its owner must finish first")
        if any(p == path or path in p.parents for p in pane_paths()):
            raise SystemExit(f"notes-task: a tmux pane is inside {path}; refusing to park")
        if last_activity(path) > time.time() - args.idle_hours * 3600:
            raise SystemExit(f"notes-task: {args.name} was recently active; refusing to park")
        dirty = not clean(path)
        if dirty and not args.checkpoint_dirty:
            raise SystemExit(f"notes-task: {path} has uncommitted changes; pass --checkpoint-dirty to commit them "
                             "to its branch before parking")
        ref = f"refs/notes-task/parked/{args.name}"
        existing = git("rev-parse", "--verify", "--quiet", ref, check=False)
        planned = {"name": args.name, "path": str(path), "branch": branch, "ref": ref,
                   "head": git("rev-parse", "HEAD", cwd=path), "checkpoint": None,
                   "evidence": None, "reason": reason}
        if args.dry_run:
            print(json.dumps({"would_park": planned, "dirty": dirty}))
            return 0
        if dirty:
            git("add", "--all", cwd=path)
            committed = subprocess.run(
                ["git", "-C", str(path), "commit", "--quiet", "-m",
                 "chore: checkpoint uncommitted work before notes-task park",
                 "-m", f"Preserved verbatim; historical, not current truth. Reason: {reason}"],
                text=True, capture_output=True)
            if committed.returncode != 0:
                git("restore", "--staged", "--", ".", cwd=path, check=False)
                raise SystemExit(f"notes-task: checkpoint commit failed; worktree preserved unchanged: "
                                 f"{committed.stderr.strip()}")
            if not clean(path):
                raise SystemExit(f"notes-task: {path} is still dirty after checkpoint; preserving it")
            planned["checkpoint"] = planned["head"] = git("rev-parse", "HEAD", cwd=path)
        tip = planned["head"]
        if git("rev-parse", f"refs/heads/{branch}") != tip:
            raise SystemExit(f"notes-task: {branch} does not match {path} HEAD; refusing to park")
        if existing and existing != tip:
            raise SystemExit(f"notes-task: {ref} already pins {existing}; refusing to overwrite")
        if not existing:
            git("update-ref", "--create-reflog", "-m", f"notes-task park {branch}: {reason}", ref, tip, "")
        if git("rev-parse", ref) != tip:
            raise SystemExit(f"notes-task: {ref} does not pin {tip}; worktree preserved")
        moved = move_ignored(path)
        planned["evidence"] = str(moved) if moved else None
        remove_worktree(path, tip)
        print(json.dumps({"parked": planned}))
        return 0
    finally:
        release_publisher_lock(descriptor)


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
        print(f"{'would remove' if args.dry_run else 'remove'} worktree {path.name} ({branch})")
        if args.dry_run:
            continue
        move_ignored(path)
        remove_worktree(path, git("rev-parse", f"refs/heads/{branch}"))
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


def retention_inventory(task_ids=(), idle_hours=2.0):
    """Read-only local retention view; no fetch, Git mutation, or deletion authority."""
    global NOTES
    original = NOTES
    result = {"schema": 1, "complete": True, "items": [], "errors": [],
              "publication_basis": "local origin/main; no network refresh"}
    try:
        paths, branches = live_claims(strict=True)
        pane_result = subprocess.run([TMUX, "list-panes", "-a", "-F", "#{pane_current_path}"],
                                     text=True, capture_output=True, timeout=10)
        if pane_result.returncode:
            raise ValueError("tmux pane inventory unavailable")
        panes = [Path(p).resolve() for p in pane_result.stdout.splitlines() if p]
        for repo in sorted({NOTES, AGENT_NOTES}):
            if not repo.is_dir():
                continue
            NOTES = repo
            for entry in worktrees():
                path = Path(entry["worktree"]).resolve()
                branch = entry.get("branch", "").removeprefix("refs/heads/")
                if path.parent != ROOT or not branch.startswith("docs/"):
                    continue
                task_id = path.name
                if task_ids and task_id not in task_ids:
                    continue
                holds = []
                if str(path) in paths or branch in branches:
                    holds.append("live_owner")
                if any(p == path or path in p.parents for p in panes):
                    holds.append("pane")
                if not clean(path):
                    holds.append("dirty")
                if not published(branch):
                    holds.append("unpublished")
                if last_activity(path) > time.time() - idle_hours * 3600:
                    holds.append("recent")
                result["items"].append({"task_id": task_id, "path": str(path), "branch": branch,
                                        "repository": str(repo), "holds": holds})
    except (SystemExit, OSError, ValueError, subprocess.SubprocessError) as error:
        result["complete"] = False
        result["errors"].append(str(error))
    finally:
        NOTES = original
    return result


def cmd_inventory(args):
    result = retention_inventory(args.task_id, args.idle_hours)
    print(json.dumps(result))
    return 0 if result["complete"] else 1


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
    p = sub.add_parser("inventory", help="Read-only structured retention inventory using local refs")
    p.add_argument("--task-id", action="append", default=[])
    p.add_argument("--idle-hours", type=float, default=2.0)
    p = sub.add_parser("park", help="Remove an idle unowned worktree, keeping its branch and a pinned parked ref")
    p.add_argument("name", help="worktree directory name under the notes worktree root")
    p.add_argument("--reason", required=True)
    p.add_argument("--checkpoint-dirty", action="store_true",
                   help="commit uncommitted changes to the branch before parking")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--idle-hours", type=float, default=2.0)
    args = parser.parse_args()
    return {"open": cmd_open, "publish": cmd_publish, "prune": cmd_prune,
            "inventory": cmd_inventory, "park": cmd_park}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
