#!/usr/bin/env python3
"""Exercise only the autosync block, never actual shell startup or network tools."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
ZSH = shutil.which("zsh")
BASH = shutil.which("bash")
TEMPLATE = Path(os.environ.get("DOTS_AUTOSYNC_TEST_TEMPLATE", ROOT / "templates/.zshrc"))


@unittest.skipUnless(ZSH and BASH, "zsh and bash are required")
class AutosyncTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="zshrc-autosync-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.dots = self.home / "dev/repos/dots"
        self.notes = self.home / "dev/repos/notes"
        (self.dots / ".git").mkdir(parents=True)
        (self.notes / ".git").mkdir(parents=True)
        (self.dots / "bin").mkdir()
        (self.dots / "setup").mkdir()
        self.state = self.home / "state/dots-sync"
        self.done = self.home / "done.json"
        self.env = {
            "HOME": str(self.home), "PATH": str(self.bin),
            "XDG_STATE_HOME": str(self.home / "state"),
            "TMPDIR": str(self.home), "TEST_HOME": str(self.home),
        }
        # Only these real utilities are available. In particular no real git,
        # provider, setup, or login-shell command can be reached through PATH.
        for name in ("awk", "mkdir", "mv", "rm", "rmdir", "date", "env"):
            (self.bin / name).symlink_to(shutil.which(name))
        (self.bin / "bash").symlink_to(BASH)
        (self.bin / "python3").symlink_to(sys.executable)
        self.executable(self.bin / "hostname", "#!/bin/sh\nprintf 'fixture-host\\n'\n")
        self.executable(self.bin / "ps", "#!/bin/sh\nprintf 'fixture-start\\n'\n")
        self.executable(self.bin / "git", f"#!{sys.executable}\n" + '''import json, os, sys
from pathlib import Path
home = Path(os.environ['TEST_HOME'])
args = sys.argv[1:]
assert args[0] == '-C' and Path(args[1]) in (home/'dev/repos/dots', home/'dev/repos/notes'), args
command = args[2:]
with (home/'git.jsonl').open('a') as log:
    log.write(json.dumps(args) + '\\n')
if command == ['rev-parse', 'HEAD']:
    print('fixed-head')
elif command not in (['status', '--short', '--untracked-files=no'],
                     ['-c', 'rebase.autoStash=false', 'pull', '--rebase'],
                     ['-c', 'rebase.autoStash=false', 'pull', '--no-rebase', '--no-edit'],
                     ['push']):
    raise SystemExit('unexpected fake git command: ' + repr(command))
''')
        # Real sync script, with cleanup and setup replaced by inert receipts.
        shutil.copyfile(ROOT / "bin/dots-sync.sh", self.dots / "bin/real-sync.sh")
        self.executable(self.dots / "bin/dots-sync.sh", f"#!{sys.executable}\n" + f'''import json, os, subprocess, sys
from pathlib import Path
home = Path(os.environ['TEST_HOME'])
(home/'args.json').write_text(json.dumps(sys.argv[1:]))
assert not sys.stdin.read(), 'automatic invocation must close stdin'
result = subprocess.run([{BASH!r}, str(home/'dev/repos/dots/bin/real-sync.sh'), *sys.argv[1:]], timeout=5)
(home/'done.json').write_text(json.dumps(result.returncode))
sys.exit(result.returncode)
''')
        (self.dots / "bin/notes-task.py").write_text('''import os, sys
from pathlib import Path
assert sys.argv[1:] == ['prune']
Path(os.environ['TEST_HOME'], 'pruned').write_text('fake cleanup only')
''')
        self.executable(self.dots / "setup/llm.sh", '''#!/bin/bash
[[ "$DOTS_SETUP_ENV_ONLY" == 1 && "$LLM_LINK_ONLY" == 1 ]] || exit 1
printf 'fake link setup only\\n' > "$TEST_HOME/setup-ran"
''')
        template = TEMPLATE.read_text()
        start = template.index("# Sync in the background")
        end = template.index("# Report deferred or failed background warmup", start)
        self.block = self.home / "autosync.zsh"
        self.block.write_text(template[start:end])

    @staticmethod
    def executable(path, content):
        path.write_text(content)
        path.chmod(0o755)

    def run_auto(self, role="work", age=None, should_run=True):
        env = dict(self.env)
        if role is not None:
            env["MACHINE_CLASS"] = role
        if age is not None:
            self.state.mkdir(parents=True)
            (self.state / "last-attempt").write_text(str(int(time.time()) - age))
        # -d -f disables global/user startup files; source only the extracted block.
        result = subprocess.run([ZSH, "-dfc", 'source "$1"', "test", str(self.block)],
                                env=env, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        if should_run:
            deadline = time.monotonic() + 8
            while not self.done.exists() and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertTrue(self.done.exists(), self.log())
            self.assertEqual(json.loads(self.done.read_text()), 0, self.log())
        else:
            self.assertFalse((self.home / "args.json").exists())
            self.assertFalse((self.home / "git.jsonl").exists())

    def log(self):
        path = self.state / "sync.log"
        return path.read_text() if path.exists() else "no fixture sync log"

    def assert_sync_and_setup(self):
        calls = [json.loads(line) for line in (self.home / "git.jsonl").read_text().splitlines()]
        self.assertEqual(sum(call[-1] == "push" for call in calls), 2)
        self.assertTrue((self.home / "setup-ran").exists())
        self.assertTrue((self.state / "last-attempt").exists())
        self.assertFalse((self.state / "lock").exists())

    def test_work_auto_preserves_and_still_syncs_and_sets_up(self):
        self.run_auto()
        self.assertEqual(json.loads((self.home / "args.json").read_text()), ["--quiet", "--no-prune"])
        self.assertFalse((self.home / "pruned").exists())
        self.assertIn("pruning skipped (--no-prune)", self.log())
        self.assert_sync_and_setup()

    def test_personal_auto_keeps_existing_default(self):
        self.run_auto(role="personal")
        self.assertEqual(json.loads((self.home / "args.json").read_text()), ["--quiet"])
        self.assertTrue((self.home / "pruned").exists())
        self.assert_sync_and_setup()

    def test_unset_role_keeps_existing_default(self):
        self.run_auto(role=None)
        self.assertTrue((self.home / "pruned").exists())

    def test_other_role_keeps_existing_default(self):
        self.run_auto(role="other")
        self.assertTrue((self.home / "pruned").exists())

    def test_recent_attempt_still_defers(self):
        self.run_auto(age=21500, should_run=False)
        self.assertFalse((self.state / "sync.log").exists())

    def test_old_attempt_still_runs_preserving(self):
        self.run_auto(age=21700)
        self.assertFalse((self.home / "pruned").exists())
        self.assert_sync_and_setup()

    def test_missing_sync_binary_still_does_nothing(self):
        (self.dots / "bin/dots-sync.sh").unlink()
        self.run_auto(should_run=False)
        self.assertFalse(self.state.exists())

    def test_unwritable_state_still_does_nothing(self):
        self.state.parent.mkdir()
        self.state.write_text("not a directory")
        self.run_auto(should_run=False)

    def test_explicit_manual_work_default_still_prunes(self):
        env = dict(self.env, MACHINE_CLASS="work")
        result = subprocess.run([str(self.dots / "bin/dots-sync.sh"), "--quiet"], env=env,
                                input="", capture_output=True, text=True, timeout=8)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.home / "pruned").exists())
        self.assert_sync_and_setup()

    def test_explicit_manual_work_no_prune_still_preserves(self):
        env = dict(self.env, MACHINE_CLASS="work")
        result = subprocess.run([str(self.dots / "bin/dots-sync.sh"), "--quiet", "--no-prune"],
                                env=env, input="", capture_output=True, text=True, timeout=8)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.home / "pruned").exists())
        self.assert_sync_and_setup()


if __name__ == "__main__":
    unittest.main()
