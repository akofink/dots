#!/usr/bin/env python3
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bin" / "personal-action-list.py"


class PersonalActionListTests(unittest.TestCase):
    def run_helper(self, path: Path, host: str = "akmac", machine_class: str = "personal") -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["PERSONAL_ACTION_LIST_FILE"] = str(path)
        env["PERSONAL_ACTION_HOST"] = host
        env["MACHINE_CLASS"] = machine_class
        return subprocess.run(["python3", str(SCRIPT)], env=env, text=True, capture_output=True, check=True)

    def test_selects_current_and_any_host_open_actions_without_consuming(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "actions.md"
            source = (
                "## Machine-wide actions (by host)\n"
                "### Operator actions\n"
                "#### akmac\n- [ ] local action\n"
                "#### akwin\n- [ ] other host action\n"
                "#### any host\n- [ ] shared action\n"
                "### Agent follow-ups\n"
                "#### akmac\n- [x] resolved action\n- [ ] local follow-up\n"
                "#### any host\n- [ ] shared follow-up\n"
            )
            path.write_text(source, encoding="utf-8")

            result = self.run_helper(path)

            self.assertIn("local action", result.stdout)
            self.assertIn("shared action", result.stdout)
            self.assertIn("local follow-up", result.stdout)
            self.assertIn("shared follow-up", result.stdout)
            self.assertNotIn("other host action", result.stdout)
            self.assertNotIn("resolved action", result.stdout)
            self.assertEqual(path.read_text(encoding="utf-8"), source)

    def test_generic_local_pointer_resolves_the_source_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            action_file = root / "source.md"
            action_file.write_text("## Machine-wide actions (by host)\n### Operator actions\n#### any host\n- [ ] configured action\n")
            pointer = root / "config" / "action-path"
            pointer.parent.mkdir()
            pointer.write_text(str(action_file) + "\n")
            env = os.environ.copy()
            env.pop("PERSONAL_ACTION_LIST_FILE", None)
            env["DOTS_PERSONAL_ACTION_POINTER"] = str(pointer)
            env["PERSONAL_ACTION_HOST"] = "akmac"
            result = subprocess.run(["python3", str(SCRIPT)], env=env, text=True, capture_output=True, check=True)
            self.assertIn("configured action", result.stdout)

    def test_work_machine_does_not_surface_personal_actions(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "actions.md"
            path.write_text("## Machine-wide actions (by host)\n### Operator actions\n#### any host\n- [ ] personal action\n")
            result = self.run_helper(path, machine_class="work")
            self.assertEqual(result.stdout, "")

    def test_missing_file_prints_nothing(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_helper(Path(tmp) / "missing.md")
            self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
