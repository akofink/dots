#!/usr/bin/env python3
"""Static checks for the opt-in Windows-native Claude/Codex setup."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "setup/windows-claude.sh"
GUIDANCE = ROOT / "templates/windows-home/CLAUDE.md"


class WindowsClaudeSetupTest(unittest.TestCase):
    def test_script_copies_canonical_common_skills_to_native_config(self):
        script = SCRIPT.read_text()
        self.assertIn('notes_repo/agents/skills/$skill', script)
        self.assertIn('"$claude_config/skills" "$codex_config/skills"', script)
        self.assertIn('cp -RL -- "$source/."', script)
        self.assertNotIn("ln -s", script)
        for skill in (
            "agent-feedback-guidance", "akagent", "agent-liaison",
            "agent-orchestrator", "coding-workflow", "durable-work-notes",
            "pr-review", "quota-axi", "skills-via-dots-notes",
            "task-self-cleanup", "tmux",
        ):
            self.assertIn(f"  {skill}\n", script)

    def test_personal_only_skill_exclusion_is_explicit_and_testable(self):
        script = SCRIPT.read_text()
        self.assertIn("Personal-only sandustry-play is not", script)
        self.assertNotIn("  sandustry-play\n", script)

    def test_guidance_uses_script_file_for_wsl_operations(self):
        guidance = GUIDANCE.read_text()
        self.assertIn("wsl.exe --distribution Ubuntu --exec bash", guidance)
        self.assertIn("do not compose nested PowerShell, WSL, and shell quoting", guidance)
        self.assertIn("notes-task open my-task", guidance)
        self.assertIn("akagent task inspect my-task", guidance)
        self.assertIn("native Windows", guidance)


if __name__ == "__main__":
    unittest.main()
