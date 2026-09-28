#!/usr/bin/env python3
"""Synchronize committed history without stashing a shared checkout's edits."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def git(repo, *args, env=None):
    return subprocess.check_output(["git", "-C", str(repo), *args], env=env)


def text(repo, *args):
    return git(repo, *args).decode().strip()


def paths(repo, *args):
    return set(filter(None, git(repo, *args).split(b"\0")))


def check_overlap(repo, old, new):
    changed = paths(repo, "diff", "--name-only", "--no-renames", "-z", old, new)
    dirty = paths(repo, "diff", "--name-only", "--no-renames", "-z")
    dirty |= paths(repo, "diff", "--cached", "--name-only", "--no-renames", "-z")
    # Include ignored files too: none belong to the synchronizer. Restrict the
    # untracked scan to incoming paths to avoid traversing the scratch checkout.
    if changed:
        dirty |= paths(repo, "--literal-pathspecs", "ls-files", "--others", "-z", "--",
                       *(os.fsdecode(p) for p in changed))
    for a in changed:
        for b in dirty:
            if a == b or a.startswith(b + b"/") or b.startswith(a + b"/"):
                raise RuntimeError("incoming/rebased changes overlap local edits: " + os.fsdecode(b))


def advance(repo, branch, old, new, remote, remote_ref):
    """Hold Git's index and ref locks across validation, push, and checkout.

    Two-tree read-tree carries unrelated staged and unstaged edits forward.
    Unlike a check followed by reset --keep, the prepared ref transaction keeps
    a concurrent commit from slipping between the HEAD check and ref update.
    """
    index = Path(text(repo, "rev-parse", "--path-format=absolute", "--git-path", "index"))
    lock = Path(str(index) + ".lock")
    fd = os.open(lock, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    transaction = None
    checkout_started = False
    success = False
    try:
        with os.fdopen(fd, "wb") as dest, index.open("rb") as source:
            shutil.copyfileobj(source, dest)
        if text(repo, "symbolic-ref", "HEAD") != branch or text(repo, "rev-parse", "HEAD") != old:
            raise RuntimeError("HEAD moved; retry after the concurrent commit")
        transaction = subprocess.Popen(
            ["git", "-C", str(repo), "update-ref", "--stdin"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)

        def send(command, expected):
            transaction.stdin.write(command + "\n")
            transaction.stdin.flush()
            if transaction.stdout.readline().strip() != expected:
                raise RuntimeError("unable to lock/update the expected branch tip")

        send("start", "start: ok")
        transaction.stdin.write(f"update {branch} {new} {old}\n")
        send("prepare", "prepare: ok")
        check_overlap(repo, old, new)
        # Explicit source and destination; never force-push or depend on
        # push.default. Rejection leaves the original checkout untouched.
        git(repo, "push", remote, f"{new}:{remote_ref}")
        if old != new:
            checkout_started = True
            git(repo, "read-tree", "-m", "-u", old, new,
                env={**os.environ, "GIT_INDEX_FILE": str(lock)})
        send("commit", "commit: ok")
        transaction.stdin.close()
        if transaction.wait() != 0:
            raise RuntimeError("ref transaction failed after checkout")
        os.replace(lock, index)
        success = True
    finally:
        if transaction is not None:
            if not transaction.stdin.closed:
                try:
                    transaction.stdin.close()  # EOF aborts an uncommitted transaction.
                except BrokenPipeError:
                    pass
            transaction.wait()
        if not success and checkout_started:
            # Do not guess a rollback after a filesystem/ref failure. Retain
            # the candidate index for explicit recovery, outside Git's lock.
            recovery_fd, recovery = tempfile.mkstemp(prefix="index.dots-sync-recovery-", dir=index.parent)
            os.close(recovery_fd)
            os.replace(lock, recovery)
            print(f"Remote push succeeded but checkout needs inspection; candidate index retained at {recovery}",
                  file=sys.stderr)
        else:
            lock.unlink(missing_ok=True)


def sync(repo, scratch_root):
    repo = Path(repo).resolve()
    branch = text(repo, "symbolic-ref", "HEAD")
    old = text(repo, "rev-parse", "HEAD")
    for name in ("MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply", "sequencer"):
        if Path(text(repo, "rev-parse", "--path-format=absolute", "--git-path", name)).exists():
            raise RuntimeError("repository operation in progress: " + name)
    if git(repo, "ls-files", "--unmerged", "-z"):
        raise RuntimeError("unmerged index entries require owner resolution")
    remote = text(repo, "for-each-ref", "--format=%(upstream:remotename)", branch)
    remote_ref = text(repo, "for-each-ref", "--format=%(upstream:remoteref)", branch)
    if not remote or remote == "." or not remote_ref.startswith("refs/heads/"):
        raise RuntimeError("a remote branch upstream is required")
    git(repo, "fetch", remote)
    upstream = text(repo, "rev-parse", "@{upstream}")
    scratch_root = Path(scratch_root)
    scratch_root.mkdir(parents=True, exist_ok=True)
    scratch = Path(tempfile.mkdtemp(prefix="sync-", dir=scratch_root))
    worktree = scratch / "checkout"
    try:
        git(repo, "worktree", "add", "--detach", str(worktree), old)
        git(worktree, "-c", "rebase.autoStash=false", "-c", "commit.gpgSign=true",
            "rebase", "--rebase-merges", "--gpg-sign", upstream)
        new = text(worktree, "rev-parse", "HEAD")
        # Verify every outgoing commit, including retained commits when no
        # rebase was necessary. Signing failures never reach the push.
        for commit in text(worktree, "rev-list", f"{upstream}..{new}").splitlines():
            git(worktree, "verify-commit", commit)
        advance(repo, branch, old, new, remote, remote_ref)
    finally:
        if worktree.exists():
            # Only our isolated rebase scratch, never the shared checkout.
            git(repo, "worktree", "remove", "--force", str(worktree))
        shutil.rmtree(scratch)


if __name__ == "__main__":
    try:
        sync(*sys.argv[1:])
    except (OSError, RuntimeError, subprocess.SubprocessError) as exc:
        print(f"Deferred dirty-checkout synchronization: {exc}", file=sys.stderr)
        sys.exit(1)
