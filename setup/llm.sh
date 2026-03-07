#!/usr/bin/env bash

if [[ -n "${LLM_SETUP_COMPLETE:-}" ]]; then
  return
fi

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  source setup/util.sh
fi

mkdir -p "$HOME/.codex" "$HOME/.rovodev"

eval_template "$DOTS_REPO/templates/dot_codex/config.toml" "$HOME/.codex/config.toml"
eval_template "$DOTS_REPO/templates/dot_codex/instructions.md" "$HOME/.codex/instructions.md"
eval_template "$DOTS_REPO/templates/dot_rovodev/config.yml" "$HOME/.rovodev/config.yml"

rovodev_agents_template="$DOTS_REPO/templates/dot_rovodev/AGENTS-home.md"
if is_truthy "${IS_WORK_MACHINE:-0}"; then
  rovodev_agents_template="$DOTS_REPO/templates/dot_rovodev/AGENTS-work.md"
fi
eval_template "$rovodev_agents_template" "$HOME/.rovodev/AGENTS.md"

export LLM_SETUP_COMPLETE=1
