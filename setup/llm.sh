#!/usr/bin/env bash

if [[ -n "${LLM_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

notes_repo="${NOTES_REPO:-"$DEV_REPOS/notes"}"
agents_template="$notes_repo/agents/global-personal.md"
if [[ "${MACHINE_CLASS:-personal}" == "work" ]]; then
  agents_template="$notes_repo/agents/global-work.md"
fi

if [[ ! -f "$agents_template" ]]; then
  fatal "Agent instructions not found at $agents_template. Clone or restore the notes repo before running llm setup."
fi

link_skill_set() {
  local destination_root="$1"
  shift

  mkdir -p "$destination_root"
  for skill_name in "$@"; do
    local skill_source="$notes_repo/.rovodev/skills/$skill_name"
    if [[ -d "$skill_source" ]]; then
      install_symlink "$skill_source" "$destination_root/$skill_name"
    fi
  done
}

common_skills=(coding-workflow pr-review)
work_skills=(atlas-updates jira-ticket-authoring working-state-cleanup)

mkdir -p \
  "$HOME/.agents" \
  "$HOME/.claude" \
  "$HOME/.codex" \
  "$HOME/.codex/rules" \
  "$HOME/.config/opencode" \
  "$HOME/.pi"

eval_template "$DOTS_REPO/templates/dot_codex/config.toml" "$HOME/.codex/config.toml" ''
eval_template "$DOTS_REPO/templates/dot_codex/instructions.md" "$HOME/.codex/instructions.md" ''
eval_template "$DOTS_REPO/templates/dot_codex/rules/dots.rules" "$HOME/.codex/rules/dots.rules" ''

install_symlink "$agents_template" "$HOME/.agents/AGENTS.md"
install_symlink "$agents_template" "$HOME/.claude/AGENTS.md"
install_symlink "$agents_template" "$HOME/.claude/CLAUDE.md"
install_symlink "$agents_template" "$HOME/.codex/AGENTS.md"
install_symlink "$agents_template" "$HOME/.config/opencode/AGENTS.md"
install_symlink "$agents_template" "$HOME/.pi/AGENTS.md"

link_skill_set "$HOME/.agents/skills" "${common_skills[@]}"
link_skill_set "$HOME/.claude/skills" "${common_skills[@]}"
link_skill_set "$HOME/.codex/skills" "${common_skills[@]}"
link_skill_set "$HOME/.config/opencode/skills" "${common_skills[@]}"
link_skill_set "$HOME/.pi/skills" "${common_skills[@]}"

install_symlink "$notes_repo/dev-root-AGENTS.md" "$HOME/dev/AGENTS.md"

if [[ -f "$notes_repo/bitbucket-core-AGENTS.md" ]]; then
  install_symlink "$notes_repo/bitbucket-core-AGENTS.md" "$HOME/dev/AGENTS.bbc-core.md"
fi
if [[ -f "$notes_repo/dss-AGENTS.md" ]]; then
  install_symlink "$notes_repo/dss-AGENTS.md" "$HOME/dev/AGENTS.dss.md"
fi

if [[ "${MACHINE_CLASS:-personal}" == "work" ]]; then
  mkdir -p "$HOME/.rovodev" "$HOME/.rovo"
  eval_template "$DOTS_REPO/templates/dot_rovodev/config.yml" "$HOME/.rovodev/config.yml" ''

  install_symlink "$agents_template" "$HOME/.rovodev/AGENTS.md"
  # Rovo CLI reads global memory from ~/.rovo/; config and MCP are tool-managed.
  install_symlink "$agents_template" "$HOME/.rovo/AGENTS.md"

  link_skill_set "$HOME/.agents/skills" "${work_skills[@]}"
  link_skill_set "$HOME/.claude/skills" "${work_skills[@]}"
  link_skill_set "$HOME/.codex/skills" "${work_skills[@]}"
  link_skill_set "$HOME/.config/opencode/skills" "${work_skills[@]}"
  link_skill_set "$HOME/.pi/skills" "${work_skills[@]}"
  link_skill_set "$HOME/.rovodev/skills" "${common_skills[@]}" "${work_skills[@]}"
  link_skill_set "$HOME/dev/.rovodev/skills" "${common_skills[@]}"
  link_skill_set "$HOME/dev/.rovodev/skills" "${work_skills[@]}"
fi

export LLM_SETUP_COMPLETE=1
