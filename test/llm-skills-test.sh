#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

notes_repo="$tmpdir/notes"
home="$tmpdir/home"
mkdir -p "$notes_repo/agents/skills" "$notes_repo/agents/guidance" "$home/dev"
printf 'global instructions\n' > "$notes_repo/agents/global-personal.md"
printf 'work instructions\n' > "$notes_repo/agents/global-work.md"
printf 'personal development guidance\n' > "$notes_repo/agents/guidance/dev-root-personal.md"
printf 'work development guidance\n' > "$notes_repo/agents/guidance/dev-root-work.md"
printf 'Bitbucket Cloud core guidance\n' > "$notes_repo/agents/guidance/bitbucket-core.md"
printf 'DSS guidance\n' > "$notes_repo/agents/guidance/dss.md"

common_skills=(akagent agent-orchestrator coding-workflow managing-1password-cli pr-review skills-via-dots-notes tmux)
work_skills=(atlas-updates confluence-work-blog elbow-pits-oncall jira-ticket-authoring querying-bbc-core-reporting-db slack-mcp)
for skill_name in "${common_skills[@]}" "${work_skills[@]}"; do
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

test "$(readlink "$home/dev/AGENTS.md")" = "$notes_repo/agents/guidance/dev-root-personal.md"

env \
  HOME="$home" \
  DOTS_REPO="$repo_root" \
  NOTES_REPO="$notes_repo" \
  ENV_SETUP_COMPLETE=1 \
  MACHINE_CLASS=work \
  LLM_LINK_ONLY=1 \
  bash "$repo_root/setup/llm.sh"

test "$(readlink "$home/dev/AGENTS.md")" = "$notes_repo/agents/guidance/dev-root-work.md"
test "$(readlink "$home/dev/AGENTS.bbc-core.md")" = "$notes_repo/agents/guidance/bitbucket-core.md"
test "$(readlink "$home/dev/AGENTS.dss.md")" = "$notes_repo/agents/guidance/dss.md"

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
