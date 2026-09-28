#!/usr/bin/env python3
"""Real disposable clones, signing, conflicts, and concurrent Git mutations."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

HELPER = Path(__file__).resolve().parents[1] / "bin/dots-sync-dirty.py"


class DirtySyncTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = {**os.environ, "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull}
        self.remote = self.root / "remote.git"
        self.repo = self.root / "local"
        self.peer = self.root / "peer"
        self.run_cmd("ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(self.root / "key"))
        (self.root / "signers").write_text("test@example.com " + (self.root / "key.pub").read_text())
        self.g(self.root, "init", "--bare", "--initial-branch=main", str(self.remote))
        self.g(self.root, "clone", str(self.remote), str(self.repo))
        self.configure(self.repo)
        for name in ("dirty", "incoming", "local-only"):
            (self.repo / name).write_text("baseline\n")
        self.commit(self.repo, "initial")
        self.g(self.repo, "push", "-u", "origin", "main")
        self.g(self.root, "clone", str(self.remote), str(self.peer))
        self.configure(self.peer)

    def run_cmd(self, *args, **kwargs):
        return subprocess.check_output(args, env=self.env, stderr=subprocess.STDOUT, **kwargs)

    def g(self, repo, *args):
        return self.run_cmd("git", "-C", str(repo), *args)

    def configure(self, repo):
        for key, value in {
            "user.name": "test", "user.email": "test@example.com", "commit.gpgsign": "true",
            "gpg.format": "ssh", "user.signingkey": str(self.root / "key"),
            "gpg.ssh.allowedSignersFile": str(self.root / "signers"),
        }.items():
            self.g(repo, "config", key, value)

    def commit(self, repo, message):
        self.g(repo, "add", "--all")
        self.g(repo, "commit", "-m", message)
        return self.g(repo, "rev-parse", "HEAD")

    def diverge(self):
        (self.repo / "local-only").write_text("local committed work\n")
        self.commit(self.repo, "local work")
        (self.peer / "incoming").write_text("remote committed work\n")
        self.commit(self.peer, "remote work")
        self.g(self.peer, "push")

    def dirty(self):
        (self.repo / "dirty").write_text("staged content\n")
        self.g(self.repo, "add", "dirty")
        (self.repo / "dirty").write_text("unstaged content\n")
        (self.repo / "untracked").write_text("keep untracked\n")
        return self.snapshot()

    def snapshot(self):
        return (self.g(self.repo, "diff", "--binary"),
                self.g(self.repo, "diff", "--cached", "--binary"),
                (self.repo / "untracked").read_bytes())

    def sync(self, succeeds=True):
        result = subprocess.run(["python3", str(HELPER), str(self.repo), str(self.root / "scratch")],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0 if succeeds else 1, result.stdout + result.stderr)
        self.assertFalse((self.repo / ".git/index.lock").exists())
        self.assertEqual(len(self.g(self.repo, "worktree", "list", "--porcelain").split(b"worktree ")), 2)
        return result

    def test_diverged_signed_rebase_preserves_staged_unstaged_untracked(self):
        self.diverge()
        before = self.dirty()
        self.sync()
        self.assertEqual(before, self.snapshot())
        self.assertEqual(self.g(self.repo, "rev-parse", "HEAD"), self.g(self.remote, "rev-parse", "main"))
        self.g(self.repo, "verify-commit", "HEAD")
        self.assertEqual((self.repo / "incoming").read_text(), "remote committed work\n")

    def test_ahead_push_and_up_to_date_do_not_require_clean_index(self):
        (self.repo / "local-only").write_text("local committed work\n")
        self.commit(self.repo, "local work")
        before = self.dirty()
        self.sync()
        self.sync()
        self.assertEqual(before, self.snapshot())

    def test_fast_forward(self):
        (self.peer / "incoming").write_text("remote work\n")
        self.commit(self.peer, "remote work")
        self.g(self.peer, "push")
        before = self.dirty()
        self.sync()
        self.assertEqual(before, self.snapshot())
        self.assertEqual(self.g(self.repo, "rev-parse", "HEAD"), self.g(self.remote, "rev-parse", "main"))

    def test_overlapping_dirty_path_defers_without_push_or_checkout(self):
        self.diverge()
        before = self.dirty()
        (self.repo / "incoming").write_text("unfinished incoming edit\n")
        old = self.g(self.repo, "rev-parse", "HEAD")
        remote = self.g(self.remote, "rev-parse", "main")
        result = self.sync(False)
        self.assertIn("overlap", result.stderr)
        self.assertEqual(old, self.g(self.repo, "rev-parse", "HEAD"))
        self.assertEqual(remote, self.g(self.remote, "rev-parse", "main"))
        self.assertEqual(before[1:], self.snapshot()[1:])
        self.assertEqual((self.repo / "incoming").read_text(), "unfinished incoming edit\n")

    def test_rebase_conflict_preserves_checkout(self):
        (self.repo / "incoming").write_text("local conflict\n")
        self.commit(self.repo, "local conflict")
        (self.peer / "incoming").write_text("remote conflict\n")
        self.commit(self.peer, "remote conflict")
        self.g(self.peer, "push")
        before = self.dirty()
        old = self.g(self.repo, "rev-parse", "HEAD")
        self.sync(False)
        self.assertEqual(old, self.g(self.repo, "rev-parse", "HEAD"))
        self.assertEqual(before, self.snapshot())

    def test_signing_failure_prevents_push(self):
        self.diverge()
        before = self.dirty()
        old = self.g(self.repo, "rev-parse", "HEAD")
        remote = self.g(self.remote, "rev-parse", "main")
        self.g(self.repo, "config", "gpg.ssh.program", "/bin/false")
        self.sync(False)
        self.assertEqual(old, self.g(self.repo, "rev-parse", "HEAD"))
        self.assertEqual(remote, self.g(self.remote, "rev-parse", "main"))
        self.assertEqual(before, self.snapshot())

    def test_untracked_incoming_collision(self):
        (self.peer / "new-file").write_text("remote\n")
        self.commit(self.peer, "new file")
        self.g(self.peer, "push")
        before = self.dirty()
        (self.repo / "new-file").write_text("local untracked\n")
        self.assertIn("overlap", self.sync(False).stderr)
        self.assertEqual((self.repo / "new-file").read_text(), "local untracked\n")
        self.assertEqual(before, self.snapshot())

    def test_rejected_push_preserves_checkout(self):
        self.diverge()
        before = self.dirty()
        hook = self.remote / "hooks/pre-receive"
        hook.write_text("#!/bin/sh\nexit 1\n")
        hook.chmod(0o755)
        old = self.g(self.repo, "rev-parse", "HEAD")
        self.sync(False)
        self.assertEqual(old, self.g(self.repo, "rev-parse", "HEAD"))
        self.assertEqual(before, self.snapshot())

    def test_unsigned_outgoing_commit_is_not_pushed(self):
        (self.repo / "local-only").write_text("unsigned work\n")
        self.g(self.repo, "add", "local-only")
        self.g(self.repo, "-c", "commit.gpgsign=false", "commit", "-m", "unsigned")
        before = self.dirty()
        remote = self.g(self.remote, "rev-parse", "main")
        self.sync(False)
        self.assertEqual(remote, self.g(self.remote, "rev-parse", "main"))
        self.assertEqual(before, self.snapshot())

    def test_staged_new_and_renamed_files_survive(self):
        self.diverge()
        before = self.dirty()
        self.g(self.repo, "mv", "dirty", "renamed with space\nand newline")
        (self.repo / "new staged file").write_text("staged addition\n")
        self.g(self.repo, "add", "new staged file")
        before = self.snapshot()
        self.sync()
        self.assertEqual(before, self.snapshot())

    def test_existing_index_lock_is_not_removed(self):
        self.diverge()
        self.dirty()
        lock = self.repo / ".git/index.lock"
        lock.write_text("someone else's lock")
        result = subprocess.run(["python3", str(HELPER), str(self.repo), str(self.root / "scratch")],
                                env=self.env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(lock.read_text(), "someone else's lock")

    def test_existing_branch_lock_preserved_and_index_lock_released(self):
        self.diverge()
        before = self.dirty()
        lock = self.repo / ".git/refs/heads/main.lock"
        lock.write_text("someone else's ref lock")
        self.sync(False)
        self.assertEqual(lock.read_text(), "someone else's ref lock")
        self.assertEqual(before, self.snapshot())

    def wrapper(self, body):
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        wrapper = bin_dir / "git"
        wrapper.write_text('#!/bin/bash\nset -e\n' + body + '\nexec "$REAL_GIT" "$@"\n')
        wrapper.chmod(0o755)
        self.env.update(REAL_GIT=shutil.which("git"), RACE_REPO=str(self.repo),
                        RACE_FLAG=str(self.root / "race-flag"), PATH=str(bin_dir) + ":" + os.environ["PATH"])

    def test_head_movement_before_index_lock_defers(self):
        self.diverge()
        self.dirty()
        self.wrapper('''if [[ "$*" == *"verify-commit"* && ! -e "$RACE_FLAG" ]]; then
  touch "$RACE_FLAG"
  "$REAL_GIT" -C "$RACE_REPO" -c commit.gpgsign=true commit --only --allow-empty -m concurrent
fi''')
        self.assertIn("HEAD moved", self.sync(False).stderr)
        self.assertEqual(self.g(self.repo, "log", "-1", "--format=%s").strip(), b"concurrent")

    def test_edit_arriving_during_push_is_preserved(self):
        self.diverge()
        self.dirty()
        old = self.g(self.repo, "rev-parse", "HEAD")
        self.wrapper('''if [[ "$*" == *" push "* && ! -e "$RACE_FLAG" ]]; then
  touch "$RACE_FLAG"
  printf 'edit during push\\n' > "$RACE_REPO/incoming"
fi''')
        result = self.sync(False)
        self.assertEqual(old, self.g(self.repo, "rev-parse", "HEAD"))
        self.assertEqual((self.repo / "incoming").read_text(), "edit during push\n")
        self.assertIn("candidate index retained", result.stderr)
        self.assertTrue(list((self.repo / ".git").glob("index.dots-sync-recovery-*")))

    def test_index_lock_prevents_concurrent_commit_during_push(self):
        self.diverge()
        before = self.dirty()
        self.wrapper('''if [[ "$*" == *" push "* && ! -e "$RACE_FLAG" ]]; then
  touch "$RACE_FLAG"
  if "$REAL_GIT" -C "$RACE_REPO" commit --allow-empty -m concurrent; then exit 90; fi
fi''')
        self.sync()
        self.assertTrue((self.root / "race-flag").exists())
        self.assertEqual(before, self.snapshot())


if __name__ == "__main__":
    unittest.main()
