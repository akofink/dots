#!/usr/bin/env python3
"""notes-task lifecycle against disposable signed clones and fake akagent/tmux."""
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1] / "bin/notes-task.py"


class NotesTaskTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.operator_notes = self.root / "operator-notes"
        self.notes = self.root / "agent-notes"
        self.wt_root = self.root / "worktrees"
        self.tasks = self.root / "tasks.json"
        self.panes = self.root / "panes.txt"
        self.sync_calls = self.root / "sync-calls"
        self.tasks.write_text(json.dumps({"tasks": []}))
        self.panes.write_text("")
        bin_dir = self.root / "bin"
        bin_dir.mkdir()
        self.fake(bin_dir / "akagent", f"""
import json, sys
data = json.load(open({str(self.tasks)!r}))
args = sys.argv[1:]
if args[:2] == ["task", "list"]:
    print(json.dumps(data))
elif args[:2] == ["task", "inspect"]:
    task = next((t for t in data["tasks"] if t["id"] == args[2]), None)
    if task is None:
        sys.exit(1)
    print(json.dumps({{"task": task, "resources": task.get("resources", [])}}))
elif args[:3] == ["task", "resource", "create"]:
    open({str(self.root / "registered")!r}, "a").write(" ".join(args) + "\\n")
""")
        self.fake(bin_dir / "tmux", f"print(open({str(self.panes)!r}).read(), end='')")
        # Stand-in for syncdots: integrate the selected checkout by merge, then push.
        self.fake(bin_dir / "syncdots", f"""
import os, subprocess, sys
repo = os.environ["NOTES_REPO"]
open({str(self.sync_calls)!r}, "a").write(repo + "\\t" + os.environ.get("DOTS_SYNC_NOTES_ONLY", "0") + "\\n")
fail_once = os.environ.get("FAKE_SYNCDOTS_FAIL_ONCE")
if fail_once and not os.path.exists(fail_once):
    open(fail_once, "w").close()
    sys.exit(1)
subprocess.check_call(["git", "-C", repo, "pull", "--quiet", "--no-rebase", "--no-edit"])
subprocess.check_call(["git", "-C", repo, "push", "--quiet"])
""")
        self.env = {**os.environ, "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
                    "NOTES_REPO": str(self.operator_notes), "NOTES_AGENT_REPO": str(self.notes),
                    "NOTES_WORKTREE_ROOT": str(self.wt_root), "XDG_STATE_HOME": str(self.root / "state"),
                    "NOTES_REPO_URL": "", "FAKE_SYNCDOTS_FAIL_ONCE": "",
                    "AKAGENT_BIN": str(bin_dir / "akagent"), "TMUX_BIN": str(bin_dir / "tmux"),
                    "SYNCDOTS_BIN": str(bin_dir / "syncdots")}
        remote = self.root / "remote.git"
        self.remote = remote
        self.git(self.root, "init", "--quiet", "--bare", "--initial-branch=main", str(remote))
        self.git(self.root, "clone", "--quiet", str(remote), str(self.operator_notes))
        self.configure(self.operator_notes)
        (self.operator_notes / ".gitignore").write_text("tmp/\n")
        (self.operator_notes / "README.md").write_text("notes\n")
        self.git(self.operator_notes, "add", "--all")
        self.git(self.operator_notes, "commit", "--quiet", "-m", "initial")
        self.git(self.operator_notes, "push", "--quiet", "-u", "origin", "main")
        self.git(self.root, "clone", "--quiet", str(remote), str(self.notes))
        self.configure(self.notes)
        self.env["NOTES_REPO_URL"] = str(remote)

    def fake(self, path, body):
        path.write_text("#!/usr/bin/env python3\n" + body)
        path.chmod(0o755)

    def git(self, repo, *args):
        return subprocess.run(["git", "-C", str(repo), *args], env=getattr(self, "env", None),
                              check=True, text=True, capture_output=True).stdout.strip()

    def configure(self, repo):
        for key, value in {"user.name": "test", "user.email": "test@example.com",
                           "commit.gpgsign": "false"}.items():
            self.git(repo, "config", key, value)

    def tool(self, *args, ok=True):
        env = dict(self.env)
        if args and args[0] == "prune":
            env["NOTES_REPO"] = str(self.notes)
        result = subprocess.run(["python3", str(TOOL), *args], env=env, text=True, capture_output=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_inventory_read_only_scoped_and_all_holds(self):
        path = self.open_and_commit("inventory-one")
        self.open_and_commit("inventory-other")
        (path / "dirty.txt").write_text("preserve me")
        self.tasks.write_text(json.dumps({"tasks": [{"id": "inventory-one", "status": "active"}]}))
        self.panes.write_text(str(path) + "\n")
        before = self.git(path, "status", "--porcelain")
        value = json.loads(self.tool("inventory", "--task-id", "inventory-one").stdout)
        self.assertTrue(value["complete"])
        self.assertEqual(len(value["items"]), 1)
        self.assertEqual(set(value["items"][0]["holds"]), {"live_owner", "pane", "dirty", "unpublished", "recent"})
        self.assertEqual(self.git(path, "status", "--porcelain"), before)
        self.assertTrue(path.exists())

    def test_inventory_ownership_failure_explicit(self):
        self.fake(Path(self.env["AKAGENT_BIN"]), "import sys; sys.exit(1)")
        result = self.tool("inventory", ok=False)
        self.assertEqual(result.returncode, 1)
        value = json.loads(result.stdout)
        self.assertFalse(value["complete"])
        self.assertTrue(value["errors"])

    def open_and_commit(self, task_id, text="report\n"):
        path = Path(self.tool("open", task_id).stdout.strip())
        (path / f"{task_id}.md").write_text(text)
        self.git(path, "add", "--all")
        self.git(path, "commit", "--quiet", "-m", f"docs: {task_id}")
        return path

    def branches(self):
        return self.git(self.notes, "for-each-ref", "--format=%(refname:short)", "refs/heads/docs/").split()

    def operator_snapshot(self):
        index = Path(self.git(self.operator_notes, "rev-parse", "--path-format=absolute", "--git-path", "index"))
        untracked = self.operator_notes / "operator-untracked.md"
        readme = self.operator_notes / "README.md"
        return {
            "branch": self.git(self.operator_notes, "branch", "--show-current"),
            "head": self.git(self.operator_notes, "rev-parse", "HEAD"),
            "refs": self.git(self.operator_notes, "for-each-ref", "--format=%(refname) %(objectname)"),
            "status": self.git(self.operator_notes, "status", "--porcelain=v2", "--untracked-files=all"),
            "index": index.read_bytes(),
            "readme": readme.read_bytes(),
            "untracked": untracked.read_bytes(),
            "cached_diff": self.git(self.operator_notes, "diff", "--cached", "--binary"),
            "worktree_diff": self.git(self.operator_notes, "diff", "--binary"),
        }

    def test_open_creates_and_reuses_worktree(self):
        path = Path(self.tool("open", "t1").stdout.strip())
        self.assertEqual(path, (self.wt_root / "t1").resolve())
        self.assertEqual(self.git(path, "branch", "--show-current"), "docs/t1")
        self.assertEqual(Path(self.git(path, "rev-parse", "--path-format=absolute", "--git-common-dir")),
                         (self.notes / ".git").resolve())
        self.assertEqual(Path(self.tool("open", "t1").stdout.strip()), path)

    def test_new_registration_declares_local_publication_contract(self):
        self.tasks.write_text(json.dumps({"tasks": [{"id": "contract", "resources": []}]}))
        path = Path(self.tool("open", "contract").stdout.strip())
        registered = (self.root / "registered").read_text()
        self.assertIn("--metadata delivery_contract=local_publication", registered)
        self.assertIn("--worktree " + str(path), registered)
        self.tool("open", "contract")
        self.assertEqual((self.root / "registered").read_text(), registered)

    def test_open_initializes_agent_clone_from_operator_remote(self):
        shutil.rmtree(self.notes)
        path = Path(self.tool("open", "bootstrap").stdout.strip())
        self.assertTrue((self.notes / ".git").is_dir())
        self.assertEqual(self.git(self.notes, "remote", "get-url", "origin"), str(self.remote))
        self.assertEqual(Path(self.git(path, "rev-parse", "--path-format=absolute", "--git-common-dir")),
                         (self.notes / ".git").resolve())
        self.assertEqual(self.git(self.operator_notes, "status", "--porcelain"), "")

    def test_open_recovers_empty_agent_clone_with_unborn_invalid_head(self):
        head = Path(self.git(self.notes, "rev-parse", "--path-format=absolute", "--git-path", "HEAD"))
        self.git(self.notes, "update-ref", "-d", "refs/heads/main")
        head.write_text("ref: refs/heads/.invalid\n")
        self.git(self.notes, "read-tree", "--empty")
        for child in self.notes.iterdir():
            if child.name != ".git":
                shutil.rmtree(child) if child.is_dir() else child.unlink()
        self.assertNotEqual(subprocess.run(["git", "-C", str(self.notes), "rev-parse", "--verify", "HEAD^{commit}"],
                                          capture_output=True).returncode, 0)
        self.git(self.operator_notes, "checkout", "-b", "operator-local")
        with (self.operator_notes / "README.md").open("a") as readme:
            readme.write(" staged operator edit\\n")
        self.git(self.operator_notes, "add", "README.md")
        with (self.operator_notes / "README.md").open("a") as readme:
            readme.write(" unstaged operator edit\\n")
        (self.operator_notes / "operator-untracked.md").write_text("untracked operator data\\n")
        operator_before = self.operator_snapshot()

        path = Path(self.tool("open", "first-use").stdout.strip())

        self.assertEqual(self.git(self.notes, "branch", "--show-current"), "main")
        self.assertEqual(self.git(self.notes, "rev-parse", "HEAD"), self.git(self.notes, "rev-parse", "origin/main"))
        self.assertEqual(self.git(self.notes, "status", "--porcelain", "--untracked-files=all"), "")
        self.assertEqual(self.git(path, "branch", "--show-current"), "docs/first-use")
        self.assertEqual(Path(self.tool("open", "first-use").stdout.strip()), path)
        self.assertEqual(self.operator_snapshot(), operator_before)

    def test_open_refuses_to_initialize_unborn_agent_clone_with_checkout_files(self):
        head = Path(self.git(self.notes, "rev-parse", "--path-format=absolute", "--git-path", "HEAD"))
        self.git(self.notes, "update-ref", "-d", "refs/heads/main")
        head.write_text("ref: refs/heads/.invalid\n")
        self.git(self.notes, "read-tree", "--empty")
        for child in self.notes.iterdir():
            if child.name != ".git":
                shutil.rmtree(child) if child.is_dir() else child.unlink()
        protected = self.notes / "keep-me.txt"
        protected.write_text("preserve this file\n")
        self.git(self.operator_notes, "checkout", "-b", "operator-local")
        with (self.operator_notes / "README.md").open("a") as readme:
            readme.write(" staged operator edit\\n")
        self.git(self.operator_notes, "add", "README.md")
        with (self.operator_notes / "README.md").open("a") as readme:
            readme.write(" unstaged operator edit\\n")
        (self.operator_notes / "operator-untracked.md").write_text("untracked operator data\\n")
        operator_before = self.operator_snapshot()

        result = self.tool("open", "unsafe", ok=False)

        self.assertIn("checkout/index state is not clean", result.stderr)
        self.assertEqual(protected.read_text(), "preserve this file\n")
        self.assertFalse((self.wt_root / "unsafe").exists())
        self.assertEqual(self.operator_snapshot(), operator_before)

    def test_open_preserves_existing_legacy_branch_binding(self):
        self.git(self.operator_notes, "branch", "docs/legacy")
        path = Path(self.tool("open", "legacy").stdout.strip())
        common = Path(self.git(path, "rev-parse", "--path-format=absolute", "--git-common-dir"))
        self.assertEqual(common, (self.operator_notes / ".git").resolve())
        self.assertEqual(self.git(path, "branch", "--show-current"), "docs/legacy")
        self.assertNotIn("docs/legacy", self.branches())

    def test_open_rejects_existing_path_on_wrong_branch_without_mutation(self):
        path = Path(self.tool("open", "t1").stdout.strip())
        before = self.git(self.notes, "rev-parse", "refs/heads/docs/t1")
        self.git(path, "checkout", "--detach")
        result = self.tool("open", "t1", ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expected docs/t1", result.stderr)
        self.assertEqual(self.git(path, "branch", "--show-current"), "")
        self.assertEqual(self.git(self.notes, "rev-parse", "refs/heads/docs/t1"), before)

    def test_open_and_publish_refuse_named_wrong_branch_without_mutation(self):
        path = Path(self.tool("open", "t1").stdout.strip())
        self.git(path, "checkout", "-b", "docs/other")
        (path / "unpublished.md").write_text("unpublished\n")
        self.git(path, "add", "unpublished.md")
        self.git(path, "commit", "--quiet", "-m", "unpublished other branch")

        before_wrong = self.git(path, "rev-parse", "HEAD")
        before_expected = self.git(self.notes, "rev-parse", "refs/heads/docs/t1")
        before_main = self.git(self.notes, "rev-parse", "main")
        before_branches = self.branches()
        for command in ("open", "publish"):
            result = self.tool(command, "t1", ok=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("expected docs/t1", result.stderr)
            self.assertEqual(self.git(path, "branch", "--show-current"), "docs/other")
            self.assertEqual(self.git(path, "rev-parse", "HEAD"), before_wrong)
            self.assertEqual(self.git(self.notes, "rev-parse", "refs/heads/docs/t1"), before_expected)
            self.assertEqual(self.git(self.notes, "rev-parse", "main"), before_main)
            self.assertEqual(self.branches(), before_branches)
            self.assertFalse(self.sync_calls.exists())

    def test_publish_merges_and_keeps_branch_an_ancestor(self):
        path = self.open_and_commit("t1")
        self.tool("publish", "t1")
        self.git(self.notes, "fetch", "--quiet")
        self.git(self.notes, "merge-base", "--is-ancestor", "docs/t1", "origin/main")
        self.assertTrue((self.notes / "t1.md").exists())
        # Later edits on the same branch publish cleanly without replaying history.
        (path / "t1.md").write_text("report v2\n")
        self.git(path, "commit", "--quiet", "-am", "docs: update")
        self.tool("publish", "t1")
        self.assertEqual((self.notes / "t1.md").read_text(), "report v2\n")

    def test_agent_publish_preserves_dirty_operator_checkout_and_only_pushes_agent_history(self):
        path = self.open_and_commit("t1")
        self.git(self.operator_notes, "checkout", "-b", "operator-local")
        with (self.operator_notes / "README.md").open("a") as readme:
            readme.write(" staged operator edit\n")
        self.git(self.operator_notes, "add", "README.md")
        with (self.operator_notes / "README.md").open("a") as readme:
            readme.write(" unstaged operator edit\n")
        (self.operator_notes / "operator-untracked.md").write_text("untracked operator data\n")
        before = self.operator_snapshot()
        initial = self.git(self.remote, "rev-parse", "refs/heads/main")
        task_commit = self.git(path, "rev-parse", "HEAD")

        result = self.tool("publish", "t1")

        self.assertIn("published docs/t1", result.stdout)
        self.assertEqual(self.operator_snapshot(), before)
        remote_head = self.git(self.remote, "rev-parse", "refs/heads/main")
        self.git(self.remote, "merge-base", "--is-ancestor", task_commit, remote_head)
        self.assertEqual(self.git(self.remote, "rev-list", "--count", f"{initial}..{remote_head}"), "2")
        self.assertNotIn("operator-untracked.md", self.git(self.remote, "ls-tree", "-r", "--name-only", remote_head))
        calls = self.sync_calls.read_text().splitlines()
        self.assertEqual(calls, [f"{self.notes.resolve()}\t1"])

    def test_publish_lock_refuses_without_merging_and_can_be_retried(self):
        self.open_and_commit("locked")
        lock = self.root / "state/notes-task/publish.lock"
        lock.parent.mkdir(parents=True, exist_ok=True)
        with lock.open("a+") as held:
            fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)
            before_main = self.git(self.notes, "rev-parse", "main")
            result = self.tool("publish", "locked", ok=False)
            self.assertIn("another notes publication is running", result.stderr)
            self.assertEqual(self.git(self.notes, "rev-parse", "main"), before_main)
            self.assertFalse(self.sync_calls.exists())
            fcntl.flock(held, fcntl.LOCK_UN)
        self.tool("publish", "locked")

    def test_non_fast_forward_sync_failure_is_retryable(self):
        path = self.open_and_commit("retry")
        initial = self.git(self.remote, "rev-parse", "refs/heads/main")
        fail_once = self.root / "sync-fail-once"
        self.env["FAKE_SYNCDOTS_FAIL_ONCE"] = str(fail_once)
        first = self.tool("publish", "retry", ok=False)
        self.assertIn("keeps the local merge for retry", first.stderr)
        local_merge = self.git(self.notes, "rev-parse", "main")
        self.assertNotEqual(local_merge, initial)
        self.assertEqual(self.git(self.remote, "rev-parse", "refs/heads/main"), initial)

        racer = self.root / "racer"
        self.git(self.root, "clone", "--quiet", str(self.remote), str(racer))
        self.configure(racer)
        (racer / "concurrent.md").write_text("concurrent remote change\n")
        self.git(racer, "add", "concurrent.md")
        self.git(racer, "commit", "--quiet", "-m", "concurrent remote change")
        self.git(racer, "push", "--quiet")

        self.tool("publish", "retry")
        remote_head = self.git(self.remote, "rev-parse", "refs/heads/main")
        self.git(self.remote, "merge-base", "--is-ancestor", self.git(path, "rev-parse", "HEAD"), remote_head)
        self.assertEqual(self.git(self.remote, "show", f"{remote_head}:concurrent.md"), "concurrent remote change")

    def test_publish_conflict_restores_canonical_main(self):
        path = self.open_and_commit("t1", "task side\n")
        (self.notes / "t1.md").write_text("main side\n")
        self.git(self.notes, "add", "t1.md")
        self.git(self.notes, "commit", "--quiet", "-m", "main edit")
        result = self.tool("publish", "t1", ok=False)
        self.assertIn("conflicts with main", result.stderr)
        self.assertEqual(self.git(self.notes, "status", "--porcelain"), "")
        self.assertTrue(path.exists())

    def test_shared_guidance_conflict_aborts_without_preference_resolution(self):
        path = Path(self.tool("open", "guidance").stdout.strip())
        guidance = path / "agents/skills/example/SKILL.md"
        guidance.parent.mkdir(parents=True)
        guidance.write_text("agent side\n")
        self.git(path, "add", "agents/skills/example/SKILL.md")
        self.git(path, "commit", "--quiet", "-m", "agent guidance edit")
        main_guidance = self.notes / "agents/skills/example/SKILL.md"
        main_guidance.parent.mkdir(parents=True)
        main_guidance.write_text("existing shared guidance\n")
        self.git(self.notes, "add", "agents/skills/example/SKILL.md")
        self.git(self.notes, "commit", "--quiet", "-m", "main guidance edit")
        before = self.git(self.notes, "rev-parse", "main")

        result = self.tool("publish", "guidance", ok=False)

        self.assertIn("conflicts in shared agent guidance", result.stderr)
        self.assertIn("Preserve both sides", result.stderr)
        self.assertEqual(self.git(self.notes, "rev-parse", "main"), before)
        self.assertEqual(self.git(self.notes, "status", "--porcelain"), "")
        self.assertTrue(path.exists())
        self.assertFalse(self.sync_calls.exists())

    def test_publish_refuses_uncommitted_worktree(self):
        path = self.open_and_commit("t1")
        (path / "t1.md").write_text("unsaved\n")
        result = self.tool("publish", "t1", ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("uncommitted", result.stderr)

    def test_publish_rejects_wrong_branch_and_missing_expected_branch_without_sync(self):
        path = Path(self.tool("open", "t1").stdout.strip())
        self.git(path, "checkout", "--detach")
        self.git(path, "branch", "-D", "docs/t1")
        before_main = self.git(self.notes, "rev-parse", "main")
        result = self.tool("publish", "t1", ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("expected docs/t1", result.stderr)
        self.assertFalse(self.sync_calls.exists())
        self.assertEqual(self.git(self.notes, "rev-parse", "main"), before_main)
        self.assertNotIn("docs/t1", self.branches())
        self.assertEqual(self.git(path, "branch", "--show-current"), "")

    def test_prune_removes_published_idle_worktree_and_keeps_evidence(self):
        path = self.open_and_commit("t1")
        self.tool("publish", "t1")
        (path / "tmp").mkdir()
        (path / "tmp" / "shot.png").write_text("evidence")
        self.tool("prune", "--idle-hours", "0")
        self.assertFalse(path.exists())
        self.assertNotIn("docs/t1", self.branches())
        self.assertEqual((self.notes / "tmp" / "t1" / "tmp" / "shot.png").read_text(), "evidence")

    def test_prune_keeps_unpublished_dirty_live_and_occupied_worktrees(self):
        self.open_and_commit("unpublished")
        dirty = self.open_and_commit("dirty")
        self.tool("publish", "dirty")
        (dirty / "dirty.md").write_text("edit\n")
        live = self.open_and_commit("live")
        self.tool("publish", "live")
        occupied = self.open_and_commit("occupied")
        self.tool("publish", "occupied")
        self.tasks.write_text(json.dumps({"tasks": [{"id": "live", "status": "waiting"}]}))
        self.panes.write_text(f"{occupied}/sub\n")
        self.tool("prune", "--idle-hours", "0")
        for name in ("unpublished", "dirty", "live", "occupied"):
            self.assertTrue((self.wt_root / name).exists(), name)
            self.assertIn(f"docs/{name}", self.branches())

    def test_prune_respects_idle_window(self):
        path = self.open_and_commit("t1")
        self.tool("publish", "t1")
        self.tool("prune")
        self.assertTrue(path.exists())

    def test_prune_deletes_rebased_but_published_branch(self):
        path = self.open_and_commit("t1")
        # Simulate the old flow: the same patch lands upstream under a different commit.
        self.git(self.notes, "cherry-pick", "docs/t1")
        self.git(self.notes, "push", "--quiet")
        self.git(self.notes, "worktree", "remove", str(path))
        self.tool("prune", "--idle-hours", "0")
        self.assertNotIn("docs/t1", self.branches())

    def test_prune_dry_run_changes_nothing(self):
        path = self.open_and_commit("t1")
        self.tool("publish", "t1")
        out = self.tool("prune", "--dry-run", "--idle-hours", "0").stdout
        self.assertIn("would remove worktree t1", out)
        self.assertTrue(path.exists())

    def test_prune_refuses_without_akagent(self):
        self.env["AKAGENT_BIN"] = str(self.root / "missing")
        result = self.tool("prune", "--idle-hours", "0", ok=False)
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
