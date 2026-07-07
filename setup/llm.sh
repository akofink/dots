#!/usr/bin/env bash

if [[ -n "${LLM_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

# install_llm_cli <name> <command> <url> <runner...>
#
# Installs an LLM CLI by downloading and running its installer script. Skips the
# install when <command> is already on PATH. Returns non-zero (without aborting
# the caller) when a prerequisite is missing or any step fails, so downstream
# config setup can still proceed.
install_llm_cli() {
  local name="$1"
  local command_name="$2"
  local url="$3"
  shift 3

  if command -v "$command_name" >/dev/null 2>&1; then
    echo "$name already installed; skipping."
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    warn "curl not found; skipping $name install"
    return 1
  fi

  echo "Downloading $name installer script..."

  local install_script
  if ! install_script=$(mktemp); then
    warn "Failed to create temp file for $name installer; skipping"
    return 1
  fi

  if ! curl -fL --progress-bar "$url" -o "$install_script"; then
    rm -f "$install_script"
    warn "Failed to download $name installer; skipping"
    return 1
  fi

  echo "Running $name installer (inner downloads may be silent; watch htop)..."

  if ! "$@" "$install_script"; then
    rm -f "$install_script"
    warn "Failed to run $name installer; skipping"
    return 1
  fi

  rm -f "$install_script"
}

# Installs the Pi Coding Agent via npm. Skips when `pi` is already on PATH and
# warns (without aborting) when npm is missing or the install fails.
install_pi_coding_agent() {
  if command -v pi >/dev/null 2>&1; then
    echo "Pi Coding Agent already installed; skipping."
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    warn "npm not found; skipping Pi Coding Agent install"
    return 1
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
    warn "Failed to install Pi Coding Agent; skipping"
    return 1
  fi
}

# install_agent_skill <name> <skill_dir> <skills-add-args...>
#
# Installs a global agent skill via `npx skills add`. Skips when the skill is
# already present under ~/.agents/skills/<skill_dir>, and warns (without
# aborting) when npx is missing or the install fails.
install_agent_skill() {
  local name="$1"
  local skill_dir="$2"
  shift 2

  if [[ -d "$HOME/.agents/skills/$skill_dir" ]]; then
    echo "Agent skill $name already installed; skipping."
    return 0
  fi

  if ! command -v npx >/dev/null 2>&1; then
    warn "npx not found; skipping $name agent skill install"
    return 1
  fi

  echo "Installing agent skill: $name ..."

  if ! npx -y skills add --yes "$@" -g; then
    warn "Failed to install $name agent skill; skipping"
    return 1
  fi
}

# Clones (or fast-forward updates) a git-backed LLM accessory repo. Warns
# (without aborting) when the clone or update fails so config setup can proceed.
clone_llm_accessory() {
  local url="$1"
  local destination="$2"

  mkdir -p "$(dirname -- "$destination")"
  if [[ ! -d "$destination/.git" ]]; then
    echo "Cloning $(basename "$url" .git) to $destination ..."
    if ! git clone "$url" "$destination"; then
      warn "Failed to clone $(basename "$url" .git); skipping"
      return 1
    fi
  else
    echo "Updating $(basename "$destination") ..."
    if ! git -C "$destination" pull --ff-only; then
      warn "Failed to update $(basename "$destination"); skipping"
      return 1
    fi
  fi
}

# Tool installs are best-effort: each helper skips work that is already present
# and warns instead of aborting on failure. The `|| true` guards keep a single
# failed install from tripping `set -e` and skipping the config setup below.
echo "→ Installing Claude Code CLI..."
install_llm_cli "Claude Code" claude "https://claude.ai/install.sh" bash || true

echo "→ Installing Codex CLI..."
install_llm_cli "Codex" codex "https://chatgpt.com/codex/install.sh" env CODEX_NON_INTERACTIVE=1 sh || true

echo "→ Installing Pi Coding Agent..."
install_pi_coding_agent || true

echo "→ Installing treehouse..."
install_llm_cli "treehouse" treehouse "https://kunchenguid.github.io/treehouse/install.sh" sh || true

echo "→ Installing AXI skill..."
install_agent_skill "AXI" axi kunchenguid/axi || true

echo "→ Installing gh-axi skill..."
install_agent_skill "gh-axi" gh-axi kunchenguid/gh-axi --skill gh-axi || true

echo "→ Installing chrome-devtools-axi skill..."
install_agent_skill "chrome-devtools-axi" chrome-devtools-axi kunchenguid/chrome-devtools-axi --skill chrome-devtools-axi || true

echo "→ Cloning firstmate (if needed)..."
clone_llm_accessory "https://github.com/kunchenguid/firstmate.git" "$DEV_REPOS/firstmate" || true

if [[ -z "${OPENCODE_SETUP_COMPLETE:-}" ]]; then
  # opencode.sh returns non-zero (without setting its guard) when the install is
  # skipped or fails; tolerate that so the config linking below still runs.
  # shellcheck source=setup/opencode.sh
  source "$script_dir/opencode.sh" || true
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

common_skills=(agent-orchestrator coding-workflow no-mistakes pr-review skills-via-dots-notes tmux)
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
