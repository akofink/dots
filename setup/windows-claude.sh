#!/usr/bin/env bash

# Copy selected common skills and Windows-specific global guidance into native
# Windows Claude/Codex config. Run inside WSL; do not link WSL config directories.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dots_repo=$(cd -- "$script_dir/.." && pwd)
notes_repo=${NOTES_REPO:-"$HOME/dev/repos/notes"}
windows_home=${WINDOWS_HOME:-}

if [[ -z "$windows_home" ]]; then
  echo 'Set WINDOWS_HOME to the Windows home path (for example C:\\Users\\name).' >&2
  exit 2
fi
if ! command -v wslpath >/dev/null 2>&1; then
  echo 'This setup must run inside WSL with wslpath available.' >&2
  exit 2
fi
if [[ ! -d "$notes_repo/agents/skills" ]]; then
  echo "Canonical skills directory not found: $notes_repo/agents/skills" >&2
  exit 1
fi

windows_home_linux=$(wslpath -u "$windows_home")
: "${windows_home_linux:?wslpath returned an empty Windows home path}"
claude_config="$windows_home_linux/.claude"
codex_config="$windows_home_linux/.codex"
mkdir -p "$claude_config/skills" "$codex_config/skills"

# Keep this list intentionally explicit. Personal-only sandustry-play is not
# distributed to work machines, even if it later appears in the notes repo.
common_skills=(
  agent-feedback-guidance
  akagent
  agent-liaison
  agent-orchestrator
  coding-workflow
  durable-work-notes
  pr-review
  quota-axi
  skills-via-dots-notes
  task-self-cleanup
  tmux
)
for skill in "${common_skills[@]}"; do
  source="$notes_repo/agents/skills/$skill"
  [[ -f "$source/SKILL.md" ]] || { echo "Missing canonical skill: $source/SKILL.md" >&2; exit 1; }
  for skill_root in "$claude_config/skills" "$codex_config/skills"; do
    rm -rf -- "${skill_root:?}/$skill"
    mkdir -p "$skill_root/$skill"
    cp -RL -- "$source/." "$skill_root/$skill/"
  done
done

cp -- "$dots_repo/templates/windows-home/CLAUDE.md" "$claude_config/CLAUDE.md"
cp -- "$dots_repo/templates/windows-home/CLAUDE.md" "$codex_config/AGENTS.md"
printf 'Installed %d common skills and Windows-native Claude/Codex guidance under %s\n' \
  "${#common_skills[@]}" "$windows_home_linux"
