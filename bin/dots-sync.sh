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
lock_ownerless_grace_seconds=30
lock_hostname=$(hostname)

if ! mkdir -p "$state_dir"; then
  printf 'Unable to create dots sync state directory: %s\n' "$state_dir" >&2
  exit 1
fi

process_start_time() {
  ps -p "$1" -o lstart= 2>/dev/null | awk '{$1 = $1; print}'
}

path_identity() {
  if [[ $(uname -s) == Darwin ]]; then
    stat -f '%d:%i' "$1" 2>/dev/null
  else
    stat -c '%d:%i' "$1" 2>/dev/null
  fi
}

path_is_older_than_grace() {
  local path=$1 path_mtime now
  if [[ $(uname -s) == Darwin ]]; then
    path_mtime=$(stat -f %m "$path" 2>/dev/null) || return 1
  else
    path_mtime=$(stat -c %Y "$path" 2>/dev/null) || return 1
  fi
  now=$(date +%s) || return 1
  [[ "$path_mtime" =~ ^[0-9]+$ && "$now" =~ ^[0-9]+$ ]] || return 1
  (( now - path_mtime >= lock_ownerless_grace_seconds ))
}

lock_is_stale() {
  local owner_pid owner_host owner_start current_start

  if [[ -d "$lock_dir/reclaim" ]] && ! path_is_older_than_grace "$lock_dir/reclaim"; then
    return 1
  fi
  if [[ -r "$lock_dir/owner" ]]; then
    IFS=$'\t' read -r owner_pid owner_host owner_start < "$lock_dir/owner" || :
    [[ "$owner_pid" =~ ^[0-9]+$ && -n "$owner_host" && -n "$owner_start" ]] || return 1
    # A lock from another host cannot be validated safely; leave it alone.
    [[ "$owner_host" == "$lock_hostname" ]] || return 1
    if kill -0 "$owner_pid" 2>/dev/null; then
      current_start=$(process_start_time "$owner_pid")
      [[ -n "$current_start" ]] || return 1
      [[ "$current_start" == "$owner_start" ]] && return 1
    fi
    return 0
  fi

  path_is_older_than_grace "$lock_dir"
}

write_lock_owner() {
  local start_time owner_tmp
  start_time=$(process_start_time "$$")
  [[ -n "$start_time" ]] || return 1
  owner_tmp="$lock_dir/owner.tmp.$$"
  if ! printf '%s\t%s\t%s\n' "$$" "$lock_hostname" "$start_time" > "$owner_tmp"; then
    return 1
  fi
  mv "$owner_tmp" "$lock_dir/owner"
}

acquire_lock() {
  local retries=0 stale_lock observed_identity reclaim_identity reclaim_claim

  while ! mkdir "$lock_dir" 2>/dev/null; do
    if [[ ! -d "$lock_dir" ]]; then
      printf 'Unable to acquire dots sync lock: %s\n' "$lock_dir" >&2
      return 1
    fi

    observed_identity=$(path_identity "$lock_dir")
    if [[ -n "$observed_identity" ]] && lock_is_stale; then
      if [[ -d "$lock_dir/reclaim" ]]; then
        # An old marker is abandoned. The nested claim refreshes its age
        # atomically so only one contender can recover this marker at a time.
        reclaim_identity=$(path_identity "$lock_dir/reclaim")
        reclaim_claim="$lock_dir/reclaim/recovering"
        if [[ -n "$reclaim_identity" ]] && mkdir "$reclaim_claim" 2>/dev/null; then
          if [[ $(path_identity "$lock_dir") == "$observed_identity" && $(path_identity "$lock_dir/reclaim") == "$reclaim_identity" ]]; then
            stale_lock="$state_dir/lock.stale.$$.${RANDOM}.$(date +%s)"
            if mv "$lock_dir" "$stale_lock" 2>/dev/null; then
              rm -rf "$stale_lock"
              printf 'Reclaimed stale dots sync lock: %s\n' "$lock_dir" >&2
              continue
            fi
          else
            rmdir "$reclaim_claim" 2>/dev/null || :
          fi
        fi
      elif mkdir "$lock_dir/reclaim" 2>/dev/null; then
        # The in-lock marker serializes reclaimers. Check the directory identity
        # again so a contender cannot move a replacement lock it did not inspect.
        if [[ $(path_identity "$lock_dir") == "$observed_identity" ]]; then
          stale_lock="$state_dir/lock.stale.$$.${RANDOM}.$(date +%s)"
          if mv "$lock_dir" "$stale_lock" 2>/dev/null; then
            rm -rf "$stale_lock"
            printf 'Reclaimed stale dots sync lock: %s\n' "$lock_dir" >&2
            continue
          else
            rmdir "$lock_dir/reclaim" 2>/dev/null || :
          fi
        else
          rmdir "$lock_dir/reclaim" 2>/dev/null || :
        fi
      fi
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

  if ! write_lock_owner; then
    printf 'Unable to record dots sync lock owner: %s\n' "$lock_dir" >&2
    rmdir "$lock_dir" 2>/dev/null || :
    return 1
  fi
}

if ! acquire_lock; then
  exit 1
fi
# Invoked indirectly by the EXIT trap.
# shellcheck disable=SC2329
cleanup_lock() {
  local owner_pid owner_host owner_start current_start
  if [[ -r "$lock_dir/owner" ]]; then
    IFS=$'\t' read -r owner_pid owner_host owner_start < "$lock_dir/owner" || :
    current_start=$(process_start_time "$$")
    if [[ "$owner_pid" == "$$" && "$owner_host" == "$lock_hostname" && "$owner_start" == "$current_start" ]]; then
      rm -f "$lock_dir/owner"
      rmdir "$lock_dir" 2>/dev/null || :
    fi
  fi
}
trap cleanup_lock EXIT

if [[ $quiet -eq 1 ]]; then
  if ! date +%s > "$state_dir/last-attempt"; then
    printf 'Unable to record dots sync attempt: %s\n' "$state_dir/last-attempt" >&2
    exit 1
  fi
fi

# Notes publishes task branches through local merges; integrating upstream with
# a merge keeps those branches ancestors of main so cleanup can prove them merged.
sync_repo() {
  local repo=$1
  local mode=${2:-rebase}
  local status
  local dirty_paths
  local pull_args=(pull --rebase)
  [[ $mode == merge ]] && pull_args=(pull --no-rebase --no-edit)

  [[ -d "$repo/.git" ]] || return 0

  dirty_paths=$(git -C "$repo" status --short --untracked-files=no)
  status=$?
  if (( status != 0 )); then
    printf 'Failed to inspect tracked changes in %s (exit %d)\n' "$repo" "$status" >&2
    return "$status"
  fi
  if [[ -n "$dirty_paths" ]]; then
    [[ $quiet -eq 1 ]] || printf 'Syncing committed changes in dirty checkout %s\n' "$repo"
    local helper
    if ! command -v python3 >/dev/null 2>&1; then
      printf 'Deferred sync of dirty checkout %s: python3 is required\n' "$repo" >&2
      return 1
    fi
    # syncdots is normally invoked through a symlink in ~/.local/bin.
    helper=$(python3 -c 'import os, sys; print(os.path.join(os.path.dirname(os.path.realpath(sys.argv[1])), "dots-sync-dirty.py"))' "${BASH_SOURCE[0]}") || return 1
    python3 "$helper" "$repo" "$notes_repo/tmp/dots-sync" "$mode"
    return $?
  fi

  if [[ $quiet -eq 1 ]]; then
    git -C "$repo" -c rebase.autoStash=false "${pull_args[@]}" >/dev/null
  else
    printf 'Syncing %s\n' "$repo"
    git -C "$repo" -c rebase.autoStash=false "${pull_args[@]}"
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

sync_status=0
sync_repo "$dots_repo" || sync_status=$?
notes_status=0
sync_repo "$notes_repo" merge || notes_status=$?
(( notes_status == 0 )) || sync_status=$notes_status
# Deterministic notes task cleanup; never fails the sync itself.
notes_task="$dots_repo/bin/notes-task.py"
if (( notes_status == 0 )) && [[ -d "$notes_repo/.git" && -f "$notes_task" ]]; then
  if [[ $quiet -eq 1 ]]; then
    NOTES_REPO="$notes_repo" python3 "$notes_task" prune >/dev/null 2>&1 || :
  else
    NOTES_REPO="$notes_repo" python3 "$notes_task" prune || printf 'Notes task prune skipped (exit %d)\n' "$?" >&2
  fi
fi
sync_llm_skill_links || sync_status=$?
exit "$sync_status"
