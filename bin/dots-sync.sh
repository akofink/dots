#!/usr/bin/env bash

quiet=0
if [[ "${1:-}" == "--quiet" ]]; then
  quiet=1
fi

dots_repo=${DOTS_REPO:-"${DEV_REPOS:-"$HOME/dev/repos"}/dots"}
notes_repo=${NOTES_REPO:-"${DEV_REPOS:-"$HOME/dev/repos"}/notes"}
state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/dots-sync
lock_dir="$state_dir/lock"

mkdir -p "$state_dir" || exit 0

if ! mkdir "$lock_dir" 2>/dev/null; then
  [[ $quiet -eq 1 ]] || printf 'dots sync is already running\n'
  exit 0
fi
trap 'rmdir "$lock_dir"' EXIT

if [[ $quiet -eq 1 ]]; then
  date +%s > "$state_dir/last-attempt" || exit 0
fi

sync_repo() {
  local repo=$1

  [[ -d "$repo/.git" ]] || return 0

  if [[ $quiet -eq 1 ]]; then
    git -C "$repo" pull --rebase --autostash >/dev/null 2>&1 || return 0
    git -C "$repo" push >/dev/null 2>&1 || return 0
  else
    printf 'Syncing %s\n' "$repo"
    git -C "$repo" pull --rebase --autostash || return 0
    git -C "$repo" push || return 0
  fi
}

sync_repo "$dots_repo"
sync_repo "$notes_repo"
