#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/bin/dots-sync.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
ln -s "$script" "$tmpdir/syncdots"
script="$tmpdir/syncdots"

setup_repo() {
  local name=$1
  local remote="$tmpdir/$name.git"
  local repo="$tmpdir/$name"

  git init --bare "$remote" >/dev/null
  git clone "$remote" "$repo" >/dev/null 2>&1
  git -C "$repo" config user.email test@example.com
  git -C "$repo" config user.name test
  printf '%s\n' "$name" > "$repo/README"
  git -C "$repo" add README
  git -C "$repo" commit -m "initial" >/dev/null
  git -C "$repo" push -u origin HEAD >/dev/null
  printf '%s\n' "$repo"
}

dots_repo=$(setup_repo dots)
notes_repo=$(setup_repo notes)
state_home="$tmpdir/state"
git_wrapper_dir="$tmpdir/bin"
git_started="$tmpdir/git-started"
mkdir -p "$git_wrapper_dir"
real_git=$(command -v git)
cat > "$git_wrapper_dir/git" <<'EOF'
#!/usr/bin/env bash
: > "$GIT_STARTED_FILE"
printf '%s\n' "$*" >> "$GIT_LOG_FILE"
exec "$REAL_GIT" "$@"
EOF
chmod +x "$git_wrapper_dir/git"

printf 'local dots\n' >> "$dots_repo/README"
git -C "$dots_repo" add README
git -C "$dots_repo" commit -m "local dots" >/dev/null
printf 'local notes\n' >> "$notes_repo/README"
git -C "$notes_repo" add README
git -C "$notes_repo" commit -m "local notes" >/dev/null
mkdir -p "$dots_repo/setup"
cat > "$dots_repo/setup/llm.sh" <<'EOF'
#!/usr/bin/env bash
printf 'reapplied\n' > "$NOTES_REPO/.sync-linked"
EOF
chmod +x "$dots_repo/setup/llm.sh"

mkdir -p "$state_home/dots-sync/lock"
(
  sleep 1
  [[ ! -e "$git_started" ]]
  rmdir "$state_home/dots-sync/lock"
) &
lock_holder=$!
git_log="$tmpdir/git.log"
PATH="$git_wrapper_dir:$PATH" \
  REAL_GIT="$real_git" GIT_STARTED_FILE="$git_started" GIT_LOG_FILE="$git_log" \
  XDG_STATE_HOME="$state_home" DOTS_REPO="$dots_repo" NOTES_REPO="$notes_repo" \
  "$script" --quiet
wait "$lock_holder"

[[ $(git -C "$dots_repo" rev-list --count '@{u}..') -eq 0 ]]
[[ $(git -C "$notes_repo" rev-list --count '@{u}..') -eq 0 ]]
[[ -f "$notes_repo/.sync-linked" ]]

lock_state="$tmpdir/lock-tests"
lock_dir="$lock_state/dots-sync/lock"
lock_host=$(hostname)
process_start_time() {
  ps -p "$1" -o lstart= 2>/dev/null | awk '{$1 = $1; print}'
}
run_with_lock() {
  local state=$1 status
  set +e
  lock_output=$(XDG_STATE_HOME="$state" DOTS_REPO="$dots_repo" NOTES_REPO="$notes_repo" "$script" --quiet 2>&1)
  status=$?
  set -e
  return "$status"
}

# A lock with a dead recorded owner is reclaimed and reported.
mkdir -p "$lock_dir"
printf '999999999\t%s\tdead process\n' "$lock_host" > "$lock_dir/owner"
run_with_lock "$lock_state" || { printf '%s\n' "$lock_output" >&2; exit 1; }
[[ "$lock_output" == *'Reclaimed stale dots sync lock'* ]]
[[ ! -e "$lock_dir" ]]

# A live owner is not displaced.
mkdir -p "$lock_dir"
printf '%s\t%s\t%s\n' "$$" "$lock_host" "$(process_start_time "$$")" > "$lock_dir/owner"
if run_with_lock "$lock_state"; then
  printf 'sync unexpectedly acquired a live-owner lock\n' >&2
  exit 1
fi
[[ "$lock_output" == *'dots sync is already running'* ]]
[[ -d "$lock_dir" && -f "$lock_dir/owner" ]]
rm -rf "$lock_dir"

# An ownerless lock older than the grace period is reclaimed.
mkdir -p "$lock_dir"
touch -t 200001010000 "$lock_dir"
run_with_lock "$lock_state" || { printf '%s\n' "$lock_output" >&2; exit 1; }
[[ "$lock_output" == *'Reclaimed stale dots sync lock'* ]]
[[ ! -e "$lock_dir" ]]

# A fresh ownerless lock remains protected by the startup grace period.
mkdir -p "$lock_dir"
if run_with_lock "$lock_state"; then
  printf 'sync unexpectedly acquired a fresh ownerless lock\n' >&2
  exit 1
fi
[[ "$lock_output" == *'dots sync is already running'* ]]
[[ -d "$lock_dir" ]]
rm -rf "$lock_dir"

# Untracked files do not block a sync.
printf 'another agent report\n' > "$notes_repo/new-report.md"
PATH="$git_wrapper_dir:$PATH" \
  REAL_GIT="$real_git" GIT_STARTED_FILE="$git_started" GIT_LOG_FILE="$git_log" \
  XDG_STATE_HOME="$tmpdir/untracked-state" DOTS_REPO="$dots_repo" NOTES_REPO="$notes_repo" \
  "$script" --quiet

# Unrelated tracked dirt is preserved while committed history and links sync.
printf 'uncommitted notes edit\n' >> "$notes_repo/README"
: > "$git_log"
set +e
failure_output=$(PATH="$git_wrapper_dir:$PATH" \
  REAL_GIT="$real_git" GIT_STARTED_FILE="$git_started" GIT_LOG_FILE="$git_log" \
  XDG_STATE_HOME="$tmpdir/dirty-state" DOTS_REPO="$dots_repo" NOTES_REPO="$notes_repo" \
  "$script" 2>&1)
failure_status=$?
set -e
[[ $failure_status -eq 0 ]] || { printf '%s\n' "$failure_output" >&2; exit 1; }
[[ $failure_output == *'Syncing committed changes in dirty checkout'* ]]
[[ $(git -C "$notes_repo" diff -- README) == *'uncommitted notes edit'* ]]
[[ $failure_output == *'Reapplying configured agent skill links'* ]]
[[ $(git -C "$dots_repo" rev-list --count '@{u}..') -eq 0 ]]
[[ -f "$notes_repo/.sync-linked" ]]
[[ $(rg -c 'pull --rebase$' "$git_log") -eq 1 ]]
if rg -- '--autostash| stash ' "$git_log"; then
  printf 'Synchronization must not stash local edits\n' >&2
  exit 1
fi

# Git failures are reported instead of being mistaken for a successful sync.
git -C "$notes_repo" remote set-url origin "$tmpdir/missing-remote.git"
set +e
failure_output=$(XDG_STATE_HOME="$tmpdir/failure-state" DOTS_REPO="$dots_repo" NOTES_REPO="$notes_repo" "$script" --quiet 2>&1)
failure_status=$?
set -e
[[ $failure_status -ne 0 ]]
[[ $failure_output == *'Deferred dirty-checkout synchronization'* ]]

# Missing repositories are intentionally harmless for a portable shell setup.
DOTS_REPO="$tmpdir/missing-dots" NOTES_REPO="$tmpdir/missing-notes" "$script" --quiet
