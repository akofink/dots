#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/bin/dots-sync.sh"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

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
PATH="$git_wrapper_dir:$PATH" \
  REAL_GIT="$real_git" GIT_STARTED_FILE="$git_started" \
  XDG_STATE_HOME="$state_home" DOTS_REPO="$dots_repo" NOTES_REPO="$notes_repo" \
  "$script" --quiet
wait "$lock_holder"

[[ $(git -C "$dots_repo" rev-list --count '@{u}..') -eq 0 ]]
[[ $(git -C "$notes_repo" rev-list --count '@{u}..') -eq 0 ]]
[[ -f "$notes_repo/.sync-linked" ]]

# Git failures are reported instead of being mistaken for a successful sync.
git -C "$notes_repo" remote set-url origin "$tmpdir/missing-remote.git"
set +e
failure_output=$(XDG_STATE_HOME="$tmpdir/failure-state" DOTS_REPO="$dots_repo" NOTES_REPO="$notes_repo" "$script" --quiet 2>&1)
failure_status=$?
set -e
[[ $failure_status -ne 0 ]]
[[ $failure_output == *'Failed to sync '* ]]

# Missing repositories are intentionally harmless for a portable shell setup.
DOTS_REPO="$tmpdir/missing-dots" NOTES_REPO="$tmpdir/missing-notes" "$script" --quiet
