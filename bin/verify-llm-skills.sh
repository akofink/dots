#!/usr/bin/env bash

set -euo pipefail

dots_repo=${DOTS_REPO:-"${DEV_REPOS:-"$HOME/dev/repos"}/dots"}
notes_repo=${NOTES_REPO:-"${DEV_REPOS:-"$HOME/dev/repos"}/notes"}

if [[ ! -f "$dots_repo/setup/llm.sh" ]]; then
  printf 'Cannot verify agent skill links: missing %s\n' "$dots_repo/setup/llm.sh" >&2
  exit 1
fi

if [[ ! -d "$notes_repo" ]]; then
  printf 'Skipping agent skill link verification: notes repository is unavailable\n'
  exit 0
fi

env \
  DOTS_REPO="$dots_repo" \
  NOTES_REPO="$notes_repo" \
  ENV_SETUP_COMPLETE=1 \
  LLM_VERIFY_ONLY=1 \
  bash "$dots_repo/setup/llm.sh"
