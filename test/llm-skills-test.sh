#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

notes_repo="$tmpdir/notes"
home="$tmpdir/home"
mkdir -p "$notes_repo/agents/skills" "$home"
printf 'global instructions\n' > "$notes_repo/agents/global-personal.md"

common_skills=(akagent agent-orchestrator coding-workflow managing-1password-cli pr-review skills-via-dots-notes tmux)
for skill_name in "${common_skills[@]}"; do
  mkdir -p "$notes_repo/agents/skills/$skill_name"
  printf '%s\n' "$skill_name" > "$notes_repo/agents/skills/$skill_name/SKILL.md"
done

run_setup() {
  env \
    HOME="$home" \
    DOTS_REPO="$repo_root" \
    NOTES_REPO="$notes_repo" \
    ENV_SETUP_COMPLETE=1 \
    MACHINE_CLASS=personal \
    LLM_LINK_ONLY=1 \
    bash "$repo_root/setup/llm.sh"
}

run_verify() {
  env \
    HOME="$home" \
    DOTS_REPO="$repo_root" \
    NOTES_REPO="$notes_repo" \
    ENV_SETUP_COMPLETE=1 \
    MACHINE_CLASS=personal \
    "$repo_root/bin/verify-llm-skills.sh"
}

run_setup
run_verify

rm "$home/.config/opencode/skills/akagent"
if run_verify >"$tmpdir/verify-output" 2>&1; then
  echo 'verification unexpectedly passed with a missing configured skill' >&2
  exit 1
fi

if ! grep -Fq 'Configured agent skill link is missing' "$tmpdir/verify-output"; then
  echo 'verification did not report the missing configured skill' >&2
  cat "$tmpdir/verify-output" >&2
  exit 1
fi

run_setup
run_verify
