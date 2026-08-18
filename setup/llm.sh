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

# install_pi_extension <name> <source>
#
# Installs a Pi extension package and keeps setup best-effort. Skips when the
# package is already registered in Pi's global package settings.
install_pi_extension() {
  local name="$1"
  local source="$2"

  if ! command -v pi >/dev/null 2>&1; then
    warn "pi not found; skipping $name install"
    return 1
  fi

  if pi list 2>/dev/null | grep -Fq -- "$source"; then
    echo "Pi extension $name already installed; skipping."
    return 0
  fi

  echo "Installing Pi extension: $name ..."

  if ! pi install "$source"; then
    warn "Failed to install $name; skipping"
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

# Tool installs are best-effort: each helper skips work that is already present
# and warns instead of aborting on failure. The `|| true` guards keep a single
# failed install from tripping `set -e` and skipping the config setup below.
# Synchronization uses LLM_LINK_ONLY to reapply links without rerunning installers.
if [[ "${LLM_LINK_ONLY:-0}" != 1 && "${LLM_VERIFY_ONLY:-0}" != 1 ]]; then
  echo "→ Installing Claude Code CLI..."
  install_llm_cli "Claude Code" claude "https://claude.ai/install.sh" bash || true

  echo "→ Installing Codex CLI..."
  install_llm_cli "Codex" codex "https://chatgpt.com/codex/install.sh" env CODEX_NON_INTERACTIVE=1 sh || true
  echo "→ Installing Pi Coding Agent..."
  install_pi_coding_agent || true
  echo "→ Installing Pi MCP Adapter..."
  install_pi_extension "Pi MCP Adapter" "npm:pi-mcp-adapter" || true
  echo "→ Installing AXI skill..."
  install_agent_skill "AXI" axi kunchenguid/axi || true
  echo "→ Installing gh-axi skill..."
  install_agent_skill "gh-axi" gh-axi kunchenguid/gh-axi --skill gh-axi || true

  if [[ -z "${OPENCODE_SETUP_COMPLETE:-}" ]]; then
    # opencode.sh returns non-zero (without setting its guard) when the install is
    # skipped or fails; tolerate that so the config linking below still runs.
    # shellcheck source=setup/opencode.sh
    source "$script_dir/opencode.sh" || true
  fi
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
    local skill_source="$notes_repo/agents/skills/$skill_name"
    if [[ ! -d "$skill_source" ]]; then
      warn "Configured agent skill source is missing: $skill_source"
      return 1
    fi
    install_symlink "$skill_source" "$destination_root/$skill_name"
  done
}

unlink_skill_set() {
  local destination_root="$1"
  shift

  for skill_name in "$@"; do
    remove_symlink_if_points_to "$destination_root/$skill_name" "$notes_repo/agents/skills/$skill_name"
  done
}

# link_pi_extensions symlinks canonical pi extensions from the notes repo into
# ~/.pi/agent/extensions where pi auto-discovers them. unlink_pi_extensions
# reverses that when the notes repo is unavailable.
link_pi_extensions() {
  local pi_extensions_source="$notes_repo/agents/pi-extensions"

  [[ -d "$pi_extensions_source" ]] || return 0
  mkdir -p "$HOME/.pi/agent/extensions"
  local extension_file
  for extension_file in "$pi_extensions_source"/*.ts; do
    [[ -f "$extension_file" ]] || continue
    install_symlink "$extension_file" "$HOME/.pi/agent/extensions/$(basename -- "$extension_file")"
  done
}

unlink_pi_extensions() {
  local pi_extensions_source="$notes_repo/agents/pi-extensions"

  [[ -d "$pi_extensions_source" ]] || return 0
  local extension_file
  for extension_file in "$pi_extensions_source"/*.ts; do
    remove_symlink_if_points_to "$HOME/.pi/agent/extensions/$(basename -- "$extension_file")" "$extension_file"
  done
}

# Rovo installs the twg (Teamwork Graph) skill bundle under a stable,
# rovo-managed path. These skills are Atlassian-work-graph specific, so they are
# linked into the other LLM CLIs on work machines only. Rovo/RovoDev discover
# them natively, so they are intentionally not linked back into the rovo dirs.
twg_skills_source="$HOME/.local/share/rovo/current/twg/skills"

# discover_twg_skills populates the global twg_skills array with the skill
# directory names currently present in twg_skills_source. Discovering at runtime
# keeps the set in sync with rovo upgrades without a hardcoded list.
twg_skills=()
discover_twg_skills() {
  twg_skills=()
  [[ -d "$twg_skills_source" ]] || return 0
  local entry
  for entry in "$twg_skills_source"/*/; do
    [[ -d "$entry" ]] || continue
    twg_skills+=("$(basename -- "${entry%/}")")
  done
}

link_twg_skill_set() {
  local destination_root="$1"

  [[ -d "$twg_skills_source" ]] || return 0
  mkdir -p "$destination_root"
  local skill_name
  for skill_name in "${twg_skills[@]}"; do
    local skill_source="$twg_skills_source/$skill_name"
    if [[ -d "$skill_source" ]]; then
      install_symlink "$skill_source" "$destination_root/$skill_name"
    fi
  done
}

# unlink_twg_skill_set removes every symlink in destination_root that points into
# twg_skills_source. It scans the destination rather than the current twg_skills
# set so stale links are cleaned up even after rovo is upgraded/removed or the
# machine switches to a personal class (where the source is not discovered).
unlink_twg_skill_set() {
  local destination_root="$1"

  [[ -d "$destination_root" ]] || return 0
  local entry
  for entry in "$destination_root"/*; do
    [[ -L "$entry" ]] || continue
    remove_symlink_if_points_to "$entry" "$twg_skills_source"
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
  remove_symlink_if_points_to "$HOME/.pi/agent/AGENTS.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/dev/AGENTS.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/dev/AGENTS.bbc-core.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/dev/AGENTS.dss.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/.rovodev/AGENTS.md" "$notes_repo"
  remove_symlink_if_points_to "$HOME/.rovo/AGENTS.md" "$notes_repo"

  unlink_skill_set "$HOME/.agents/skills" "${common_skills[@]}" "${work_skills[@]}"
  unlink_skill_set "$HOME/.claude/skills" "${common_skills[@]}" "${work_skills[@]}"
  unlink_skill_set "$HOME/.codex/skills" "${common_skills[@]}" "${work_skills[@]}"
  unlink_skill_set "$HOME/.config/opencode/skills" "${common_skills[@]}" "${work_skills[@]}"
  unlink_skill_set "$HOME/.pi/agent/skills" "${common_skills[@]}" "${work_skills[@]}"
  unlink_pi_extensions
  unlink_skill_set "$HOME/.rovodev/skills" "${common_skills[@]}" "${work_skills[@]}"
  unlink_skill_set "$HOME/dev/.rovodev/skills" "${common_skills[@]}" "${work_skills[@]}"

  local twg_dest
  for twg_dest in "${twg_skill_dests[@]}"; do
    unlink_twg_skill_set "$twg_dest"
  done
}

common_skills=(akagent agent-orchestrator coding-workflow managing-1password-cli pr-review skills-via-dots-notes tmux)
work_skills=(atlas-updates confluence-work-blog elbow-pits-oncall jira-ticket-authoring querying-bbc-core-reporting-db slack-mcp working-state-cleanup)
notes_skill_dests=(
  "$HOME/.agents/skills"
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
  "$HOME/.config/opencode/skills"
  "$HOME/.pi/agent/skills"
)
if [[ "${MACHINE_CLASS:-personal}" == "work" ]]; then
  notes_skill_dests+=(
    "$HOME/.rovodev/skills"
    "$HOME/dev/.rovodev/skills"
  )
fi

verify_skill_set() {
  local destination_root="$1"
  shift
  local failed=0
  local skill_name
  local skill_source
  local destination
  local current_target

  for skill_name in "$@"; do
    skill_source="$notes_repo/agents/skills/$skill_name"
    destination="$destination_root/$skill_name"
    if [[ ! -d "$skill_source" ]]; then
      warn "Configured agent skill source is missing: $skill_source"
      failed=1
      continue
    fi
    if [[ ! -L "$destination" ]]; then
      warn "Configured agent skill link is missing: $destination"
      failed=1
      continue
    fi
    current_target=$(readlink -- "$destination") || {
      warn "Unable to read configured agent skill link: $destination"
      failed=1
      continue
    }
    if [[ "$current_target" != "$skill_source" ]]; then
      warn "Configured agent skill link points to $current_target, expected $skill_source"
      failed=1
      continue
    fi
    if [[ ! -f "$destination/SKILL.md" ]]; then
      warn "Configured agent skill link is broken or incomplete: $destination"
      failed=1
    fi
  done

  return "$failed"
}

link_notes_skill_set() {
  local failed=0
  local destination_root
  for destination_root in "${notes_skill_dests[@]}"; do
    link_skill_set "$destination_root" "${common_skills[@]}" || failed=1
    if [[ "${MACHINE_CLASS:-personal}" == "work" ]]; then
      link_skill_set "$destination_root" "${work_skills[@]}" || failed=1
    fi
  done
  return "$failed"
}

verify_notes_skill_set() {
  local failed=0
  local destination_root
  for destination_root in "${notes_skill_dests[@]}"; do
    verify_skill_set "$destination_root" "${common_skills[@]}" || failed=1
    if [[ "${MACHINE_CLASS:-personal}" == "work" ]]; then
      verify_skill_set "$destination_root" "${work_skills[@]}" || failed=1
    fi
  done
  return "$failed"
}

finish_llm_script() {
  local status="$1"
  if [[ "${BASH_SOURCE[1]}" == "$0" ]]; then
    exit "$status"
  fi
  return "$status"
}

if [[ "${LLM_VERIFY_ONLY:-0}" == 1 || "${LLM_LINK_ONLY:-0}" == 1 ]]; then
  status=0
  if [[ "$has_notes_agents" -eq 1 ]]; then
    if [[ "${LLM_VERIFY_ONLY:-0}" != 1 ]]; then
      link_notes_skill_set || status=$?
    fi
    verify_notes_skill_set || status=$?
  else
    echo "Skipping notes-backed agent skill verification; missing $agents_template"
  fi
  export LLM_SETUP_COMPLETE=1
  finish_llm_script "$status"
fi

# Non-rovo LLM CLIs that should surface the rovo-managed twg skills on work
# machines. Rovo/RovoDev are omitted because they load the twg bundle natively.
twg_skill_dests=(
  "$HOME/.agents/skills"
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
  "$HOME/.config/opencode/skills"
  "$HOME/.pi/agent/skills"
)
discover_twg_skills

# Legacy pi locations predate ~/.pi/agent; clean links created under the old
# paths so re-runs converge on the current layout.
remove_symlink_if_points_to "$HOME/.pi/AGENTS.md" "$notes_repo"
unlink_skill_set "$HOME/.pi/skills" "${common_skills[@]}" "${work_skills[@]}"

mkdir -p \
  "$HOME/.agents" \
  "$HOME/.claude" \
  "$HOME/.codex" \
  "$HOME/.codex/rules" \
  "$HOME/.config/opencode" \
  "$HOME/.pi" \
  "$HOME/.pi/agent"

eval_template "$DOTS_REPO/templates/dot_codex/config.toml" "$HOME/.codex/config.toml"
eval_template "$DOTS_REPO/templates/dot_codex/rules/dots.rules" "$HOME/.codex/rules/dots.rules" ''
OPENCODE_WORK_CONFIG=''
if [[ "${MACHINE_CLASS:-personal}" == "work" ]]; then
  OPENCODE_WORK_CONFIG=$(< "$DOTS_REPO/templates/dot_config/opencode/work.jsonc")
fi
export OPENCODE_WORK_CONFIG
# shellcheck disable=SC2016 # Pass the variable name to envsubst, not its value.
eval_template \
  "$DOTS_REPO/templates/dot_config/opencode/opencode.jsonc" \
  "$HOME/.config/opencode/opencode.jsonc" \
  '$OPENCODE_WORK_CONFIG'
unset OPENCODE_WORK_CONFIG

# Pi settings are captured live state, re-asserted like other CLI configs so
# drift from the canonical defaults is archived rather than silently kept.
# Empty substitution list: settings.json must never expand shell variables.
eval_template \
  "$DOTS_REPO/templates/dot_pi/agent/settings.json" \
  "$HOME/.pi/agent/settings.json" \
  ''

pi_mcp_config_template="$DOTS_REPO/templates/dot_pi/agent/mcp.json"
if [[ "${MACHINE_CLASS:-personal}" == "work" ]]; then
  eval_template "$pi_mcp_config_template" "$HOME/.pi/agent/mcp.json" ''
elif [[ -f "$HOME/.pi/agent/mcp.json" ]] && cmp -s "$pi_mcp_config_template" "$HOME/.pi/agent/mcp.json"; then
  rm -f "$HOME/.pi/agent/mcp.json"
fi

# Claude uses CLAUDE.md as its single global instruction path.
remove_symlink_if_points_to "$HOME/.claude/AGENTS.md" "$notes_repo"

if [[ $has_notes_agents -eq 1 ]]; then
  install_symlink "$agents_template" "$HOME/.agents/AGENTS.md"
  install_symlink "$agents_template" "$HOME/.claude/CLAUDE.md"
  install_symlink "$agents_template" "$HOME/.codex/AGENTS.md"
  install_symlink "$agents_template" "$HOME/.config/opencode/AGENTS.md"
  install_symlink "$agents_template" "$HOME/.pi/agent/AGENTS.md"

  if [[ -f "$notes_repo/agents/claude/test-writer.md" ]]; then
    install_symlink "$notes_repo/agents/claude/test-writer.md" "$HOME/.claude/agents/test-writer.md"
  fi

  link_notes_skill_set
  link_pi_extensions

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

    link_notes_skill_set
  else
    unlink_notes_symlinks
  fi

  # twg skills are rovo-managed (not notes-backed), so link them regardless of
  # notes repo availability. When rovo is not installed the link helper is a
  # no-op and the unlink pass below clears any stale links.
  if [[ -d "$twg_skills_source" ]]; then
    for twg_dest in "${twg_skill_dests[@]}"; do
      link_twg_skill_set "$twg_dest"
    done
  else
    for twg_dest in "${twg_skill_dests[@]}"; do
      unlink_twg_skill_set "$twg_dest"
    done
  fi
else
  unlink_skill_set "$HOME/.agents/skills" "${work_skills[@]}"
  unlink_skill_set "$HOME/.claude/skills" "${work_skills[@]}"
  unlink_skill_set "$HOME/.codex/skills" "${work_skills[@]}"
  unlink_skill_set "$HOME/.config/opencode/skills" "${work_skills[@]}"
  unlink_skill_set "$HOME/.pi/agent/skills" "${work_skills[@]}"
  unlink_skill_set "$HOME/.rovodev/skills" "${common_skills[@]}" "${work_skills[@]}"
  unlink_skill_set "$HOME/dev/.rovodev/skills" "${common_skills[@]}" "${work_skills[@]}"

  # twg skills are work-only; clear them on personal machines.
  for twg_dest in "${twg_skill_dests[@]}"; do
    unlink_twg_skill_set "$twg_dest"
  done

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

if [[ "$has_notes_agents" -eq 1 ]]; then
  verify_notes_skill_set
fi

export LLM_SETUP_COMPLETE=1
