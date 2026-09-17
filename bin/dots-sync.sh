#!/usr/bin/env bash

quiet=0
if [[ "${1:-}" == "--quiet" ]]; then
  quiet=1
fi

dots_repo=${DOTS_REPO:-"${DEV_REPOS:-"$HOME/dev/repos"}/dots"}
notes_repo=${NOTES_REPO:-"${DEV_REPOS:-"$HOME/dev/repos"}/notes"}
state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/dots-sync
lock_dir="$state_dir/lock"
lock_retry_limit=5
lock_retry_delay_seconds=1

if ! mkdir -p "$state_dir"; then
  printf 'Unable to create dots sync state directory: %s\n' "$state_dir" >&2
  exit 1
fi

acquire_lock() {
  local retries=0

  while ! mkdir "$lock_dir" 2>/dev/null; do
    if [[ ! -d "$lock_dir" ]]; then
      printf 'Unable to acquire dots sync lock: %s\n' "$lock_dir" >&2
      return 1
    fi

    if (( retries >= lock_retry_limit )); then
      printf 'dots sync is already running; gave up after %d retries\n' "$lock_retry_limit" >&2
      return 1
    fi

    retries=$((retries + 1))
    [[ $quiet -eq 1 ]] || printf 'dots sync is already running; retrying in %d second(s)\n' "$lock_retry_delay_seconds" >&2
    if ! sleep "$lock_retry_delay_seconds"; then
      printf 'Interrupted while waiting for dots sync lock: %s\n' "$lock_dir" >&2
      return 1
    fi
  done
}

if ! acquire_lock; then
  exit 1
fi
cleanup_lock() {
  rmdir "$lock_dir" 2>/dev/null || :
}
trap cleanup_lock EXIT

if [[ $quiet -eq 1 ]]; then
  if ! date +%s > "$state_dir/last-attempt"; then
    printf 'Unable to record dots sync attempt: %s\n' "$state_dir/last-attempt" >&2
    exit 1
  fi
fi

sync_repo() {
  local repo=$1
  local status

  [[ -d "$repo/.git" ]] || return 0

  if [[ $quiet -eq 1 ]]; then
    git -C "$repo" pull --rebase --autostash >/dev/null
  else
    printf 'Syncing %s\n' "$repo"
    git -C "$repo" pull --rebase --autostash
  fi
  status=$?
  if (( status != 0 )); then
    printf 'Failed to sync %s during pull (exit %d)\n' "$repo" "$status" >&2
    return "$status"
  fi

  if [[ $quiet -eq 1 ]]; then
    git -C "$repo" push >/dev/null
  else
    git -C "$repo" push
  fi
  status=$?
  if (( status != 0 )); then
    printf 'Failed to sync %s during push (exit %d)\n' "$repo" "$status" >&2
    return "$status"
  fi
}

sync_llm_skill_links() {
  [[ -f "$dots_repo/setup/llm.sh" && -d "$notes_repo" ]] || return 0

  local command=(env DOTS_REPO="$dots_repo" NOTES_REPO="$notes_repo" DOTS_SETUP_ENV_ONLY=1 LLM_LINK_ONLY=1 bash "$dots_repo/setup/llm.sh")
  local status

  if [[ $quiet -eq 1 ]]; then
    "${command[@]}" >/dev/null
  else
    printf 'Reapplying configured agent skill links\n'
    "${command[@]}"
  fi
  status=$?
  if (( status != 0 )); then
    printf 'Failed to reapply configured agent skill links (exit %d)\n' "$status" >&2
    return "$status"
  fi
}

sync_repo "$dots_repo" || exit $?
sync_repo "$notes_repo" || exit $?
sync_llm_skill_links || exit $?
