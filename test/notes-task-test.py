#!/usr/bin/env python3
"""notes-task lifecycle against disposable signed clones and fake akagent/tmux."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1] / "bin/notes-task.py"


class NotesTaskTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.notes = self.root / "notes"
        self.wt_root = self.root / "worktrees"
        self.tasks = self.root / "tasks.json"
        self.panes = self.root / "panes.txt"
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
        # Stand-in for syncdots: integrate upstream by merge, then push.
        self.fake(bin_dir / "syncdots", f"""
import subprocess
repo = {str(self.notes)!r}
subprocess.check_call(["git", "-C", repo, "pull", "--quiet", "--no-rebase", "--no-edit"])
subprocess.check_call(["git", "-C", repo, "push", "--quiet"])
""")
        self.env = {**os.environ, "GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
                    "NOTES_REPO": str(self.notes), "NOTES_WORKTREE_ROOT": str(self.wt_root),
                    "AKAGENT_BIN": str(bin_dir / "akagent"), "TMUX_BIN": str(bin_dir / "tmux"),
                    "SYNCDOTS_BIN": str(bin_dir / "syncdots")}
        remote = self.root / "remote.git"
        self.git(self.root, "init", "--quiet", "--bare", "--initial-branch=main", str(remote))
        self.git(self.root, "clone", "--quiet", str(remote), str(self.notes))
        self.configure(self.notes)
        (self.notes / ".gitignore").write_text("tmp/\n")
        (self.notes / "README.md").write_text("notes\n")
        self.git(self.notes, "add", "--all")
        self.git(self.notes, "commit", "--quiet", "-m", "initial")
        self.git(self.notes, "push", "--quiet", "-u", "origin", "main")

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
        result = subprocess.run(["python3", str(TOOL), *args], env=self.env, text=True, capture_output=True)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def open_and_commit(self, task_id, text="report\n"):
        path = Path(self.tool("open", task_id).stdout.strip())
        (path / f"{task_id}.md").write_text(text)
        self.git(path, "add", "--all")
        self.git(path, "commit", "--quiet", "-m", f"docs: {task_id}")
        return path

    def branches(self):
        return self.git(self.notes, "for-each-ref", "--format=%(refname:short)", "refs/heads/docs/").split()

    def test_open_creates_and_reuses_worktree(self):
        path = Path(self.tool("open", "t1").stdout.strip())
        self.assertEqual(path, (self.wt_root / "t1").resolve())
        self.assertEqual(self.git(path, "branch", "--show-current"), "docs/t1")
        self.assertEqual(Path(self.tool("open", "t1").stdout.strip()), path)

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

    def test_publish_conflict_restores_canonical_main(self):
        path = self.open_and_commit("t1", "task side\n")
        (self.notes / "t1.md").write_text("main side\n")
        self.git(self.notes, "add", "t1.md")
        self.git(self.notes, "commit", "--quiet", "-m", "main edit")
        result = self.tool("publish", "t1", ok=False)
        self.assertIn("conflicts with main", result.stderr)
        self.assertEqual(self.git(self.notes, "status", "--porcelain"), "")
        self.assertTrue(path.exists())

    def test_publish_refuses_uncommitted_worktree(self):
        path = self.open_and_commit("t1")
        (path / "t1.md").write_text("unsaved\n")
        result = self.tool("publish", "t1", ok=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("uncommitted", result.stderr)

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
