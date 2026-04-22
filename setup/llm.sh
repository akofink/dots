#!/usr/bin/env bash

if [[ -n "${LLM_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

mkdir -p "$HOME/.config/opencode" "$HOME/.codex" "$HOME/.codex/rules" "$HOME/.rovodev"

eval_template "$DOTS_REPO/templates/dot_codex/config.toml" "$HOME/.codex/config.toml"
eval_template "$DOTS_REPO/templates/dot_codex/instructions.md" "$HOME/.codex/instructions.md"
eval_template "$DOTS_REPO/templates/dot_codex/rules/dots.rules" "$HOME/.codex/rules/dots.rules"
eval_template "$DOTS_REPO/templates/dot_rovodev/config.yml" "$HOME/.rovodev/config.yml"

agents_template="$DOTS_REPO/templates/dot_rovodev/AGENTS-home.md"
if is_truthy "${IS_WORK_MACHINE:-0}"; then
  agents_template="$DOTS_REPO/templates/dot_rovodev/AGENTS-work.md"
fi
eval_template "$agents_template" "$HOME/.config/opencode/AGENTS.md"
eval_template "$agents_template" "$HOME/.codex/AGENTS.md"
eval_template "$agents_template" "$HOME/.rovodev/AGENTS.md"

export LLM_SETUP_COMPLETE=1
