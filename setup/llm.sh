#!/usr/bin/env bash

if [[ -n "${LLM_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

install_llm_cli() {
  local name="$1"
  local url="$2"
  shift 2

  if ! command -v curl >/dev/null 2>&1; then
    fatal "curl not found; install curl before setting up LLM CLI tools"
  fi

  echo "Downloading $name installer script..."

  local install_script
  install_script=$(mktemp) || fatal "Failed to create temp file for $name installer"

  if ! curl -fL --progress-bar "$url" -o "$install_script"; then
    rm -f "$install_script"
    fatal "Failed to download $name installer"
  fi

  echo "Running $name installer (inner downloads may be silent; watch htop)..."

  if ! "$@" "$install_script"; then
    rm -f "$install_script"
    fatal "Failed to run $name installer"
  fi

  rm -f "$install_script"
}

install_pi_coding_agent() {
  if ! command -v npm >/dev/null 2>&1; then
    fatal "npm not found; install Node.js before setting up Pi Coding Agent"
  fi

  echo "Installing Pi Coding Agent (npm)..."

  if ! npm install -g \
    --ignore-scripts \
    --min-release-age=0 \
    --no-fund \
    --no-audit \
    --loglevel=error \
    --progress=false \
    @earendil-works/pi-coding-agent; then
    fatal "Failed to install Pi Coding Agent"
  fi
}

install_agent_skill() {
  local name="$1"
  shift

  if ! command -v npx >/dev/null 2>&1; then
    fatal "npx not found; install Node.js before setting up $name"
  fi

  echo "Installing agent skill: $name ..."

  if ! npx -y skills add --yes "$@" -g; then
    fatal "Failed to install $name agent skill"
  fi
}

clone_llm_accessory() {
  local url="$1"
  local destination="$2"

  mkdir -p "$(dirname -- "$destination")"
  if [[ ! -d "$destination/.git" ]]; then
    echo "Cloning $(basename "$url" .git) to $destination ..."
    git clone "$url" "$destination"
  else
    echo "Updating $(basename "$destination") ..."
    git -C "$destination" pull --ff-only
  fi
}

echo "→ Installing Claude Code CLI..."
install_llm_cli "Claude Code" "https://claude.ai/install.sh" bash

echo "→ Installing Codex CLI..."
install_llm_cli "Codex" "https://chatgpt.com/codex/install.sh" env CODEX_NON_INTERACTIVE=1 sh

echo "→ Installing Pi Coding Agent..."
install_pi_coding_agent

echo "→ Installing treehouse..."
install_llm_cli "treehouse" "https://kunchenguid.github.io/treehouse/install.sh" sh

echo "→ Installing AXI skill..."
install_agent_skill "AXI" kunchenguid/axi

echo "→ Installing gh-axi skill..."
install_agent_skill "gh-axi" kunchenguid/gh-axi --skill gh-axi

echo "→ Installing chrome-devtools-axi skill..."
install_agent_skill "chrome-devtools-axi" kunchenguid/chrome-devtools-axi --skill chrome-devtools-axi

echo "→ Cloning firstmate (if needed)..."
clone_llm_accessory "https://github.com/kunchenguid/firstmate.git" "$DEV_REPOS/firstmate"

if [[ -z "${OPENCODE_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/opencode.sh
  source "$script_dir/opencode.sh"
fi

notes_repo="$NOTES_REPO"
agents_template="$notes_repo/agents/global-personal.md"
if [[ "${MACHINE_CLASS:-personal}" == "work" ]]; then
  agents_template="$notes_repo/agents/global-work.md"
fi
has_notes_agents=1
if [[ ! -f "$agents_template" ]]; then
  has_notes_agents=0
  echo "Skipping notes-backed agent setup; missing $agents_template"
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

unlink_skill_set() {
  local destination_root="$1"
  shift

  for skill_name in "$@"; do
    remove_symlink_if_points_to "$destination_root/$skill_name" "$notes_repo/.rovodev/skills/$skill_name"
  done
}

unlink_notes_symlinks() {
  remove_symlink_if_points_to "$HOME/.agents/AGENTS.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/.claude/AGENTS.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/.claude/CLAUDE.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/.claude/agents/test-writer.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/.codex/AGENTS.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/.config/opencode/AGENTS.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/.pi/AGENTS.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/dev/AGENTS.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/dev/AGENTS.bbc-core.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/dev/AGENTS.dss.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/.rovodev/AGENTS.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/.rovo/AGENTS.md" "$notes_repo"

  unlink_skill_set "$HOME/.agents/skills" "${common_skills[@]}" "${work_skills[@]}"
  unlink_skill_set "$HOME/.claude/skills" "${common_skills[@]}" "${work_skills[@]}"
  unlink_skill_set "$HOME/.codex/skills" "${common_skills[@]}" "${work_skills[@]}"
  unlink_skill_set "$HOME/.config/opencode/skills" "${common_skills[@]}" "${work_skills[@]}"
  unlink_skill_set "$HOME/.pi/skills" "${common_skills[@]}" "${work_skills[@]}"
  unlink_skill_set "$HOME/.rovodev/skills" "${common_skills[@]}" "${work_skills[@]}"
  unlink_skill_set "$HOME/dev/.rovodev/skills" "${common_skills[@]}" "${work_skills[@]}"
}

common_skills=(coding-workflow no-mistakes pr-review tmux)
work_skills=(atlas-updates jira-ticket-authoring working-state-cleanup)

mkdir -p \
  "$HOME/.agents" \
  "$HOME/.claude" \
  "$HOME/.codex" \
  "$HOME/.codex/rules" \
  "$HOME/.config/opencode" \
  "$HOME/.pi"

eval_template "$DOTS_REPO/templates/dot_codex/config.toml" "$HOME/.codex/config.toml"
eval_template "$DOTS_REPO/templates/dot_codex/instructions.md" "$HOME/.codex/instructions.md" ''
eval_template "$DOTS_REPO/templates/dot_codex/rules/dots.rules" "$HOME/.codex/rules/dots.rules" ''
eval_template "$DOTS_REPO/templates/dot_config/opencode/opencode.jsonc" "$HOME/.config/opencode/opencode.jsonc" ''

if [[ $has_notes_agents -eq 1 ]]; then
  install_symlink "$agents_template" "$HOME/.agents/AGENTS.md"
  install_symlink "$agents_template" "$HOME/.claude/AGENTS.md"
  install_symlink "$agents_template" "$HOME/.claude/CLAUDE.md"
  install_symlink "$agents_template" "$HOME/.codex/AGENTS.md"
  install_symlink "$agents_template" "$HOME/.config/opencode/AGENTS.md"
  install_symlink "$agents_template" "$HOME/.pi/AGENTS.md"

  if [[ -f "$notes_repo/agents/claude/test-writer.md" ]]; then
    install_symlink "$notes_repo/agents/claude/test-writer.md" "$HOME/.claude/agents/test-writer.md"
  fi

  link_skill_set "$HOME/.agents/skills" "${common_skills[@]}"
  link_skill_set "$HOME/.claude/skills" "${common_skills[@]}"
  link_skill_set "$HOME/.codex/skills" "${common_skills[@]}"
  link_skill_set "$HOME/.config/opencode/skills" "${common_skills[@]}"
  link_skill_set "$HOME/.pi/skills" "${common_skills[@]}"

  dev_agents_template="$notes_repo/dev-root-personal-AGENTS.md"
  if [[ "${MACHINE_CLASS:-personal}" == "work" ]]; then
    dev_agents_template="$notes_repo/dev-root-AGENTS.md"
  fi
  if [[ -f "$dev_agents_template" ]]; then
    install_symlink "$dev_agents_template" "$HOME/dev/AGENTS.md"
  fi
fi

if [[ "${MACHINE_CLASS:-personal}" == "work" ]]; then
  if [[ $has_notes_agents -eq 1 ]]; then
    if [[ -f "$notes_repo/bitbucket-core-AGENTS.md" ]]; then
      install_symlink "$notes_repo/bitbucket-core-AGENTS.md" "$HOME/dev/AGENTS.bbc-core.md"
    fi
    if [[ -f "$notes_repo/dss-AGENTS.md" ]]; then
      install_symlink "$notes_repo/dss-AGENTS.md" "$HOME/dev/AGENTS.dss.md"
    fi
  fi

  mkdir -p "$HOME/.rovodev" "$HOME/.rovo"
  eval_template "$DOTS_REPO/templates/dot_rovodev/config.yml" "$HOME/.rovodev/config.yml" ''

  if [[ $has_notes_agents -eq 1 ]]; then
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
  else
    unlink_notes_symlinks
  fi
else
  unlink_skill_set "$HOME/.agents/skills" "${work_skills[@]}"
  unlink_skill_set "$HOME/.claude/skills" "${work_skills[@]}"
  unlink_skill_set "$HOME/.codex/skills" "${work_skills[@]}"
  unlink_skill_set "$HOME/.config/opencode/skills" "${work_skills[@]}"
  unlink_skill_set "$HOME/.pi/skills" "${work_skills[@]}"
  unlink_skill_set "$HOME/.rovodev/skills" "${common_skills[@]}" "${work_skills[@]}"
  unlink_skill_set "$HOME/dev/.rovodev/skills" "${common_skills[@]}" "${work_skills[@]}"

  remove_symlink_if_points_to "$HOME/dev/AGENTS.bbc-core.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/dev/AGENTS.dss.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/.rovodev/AGENTS.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/.rovo/AGENTS.md" "$notes_repo"
  if [[ $has_notes_agents -eq 0 ]]; then
    unlink_notes_symlinks
  fi
  if [[ -f "$HOME/.rovodev/config.yml" ]] && cmp -s "$DOTS_REPO/templates/dot_rovodev/config.yml" "$HOME/.rovodev/config.yml"; then
    rm -f "$HOME/.rovodev/config.yml"
  fi
fi

export LLM_SETUP_COMPLETE=1
