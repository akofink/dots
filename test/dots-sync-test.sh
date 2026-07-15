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

printf 'local dots\n' >> "$dots_repo/README"
git -C "$dots_repo" add README
git -C "$dots_repo" commit -m "local dots" >/dev/null
printf 'local notes\n' >> "$notes_repo/README"
git -C "$notes_repo" add README
git -C "$notes_repo" commit -m "local notes" >/dev/null

DOTS_REPO="$dots_repo" NOTES_REPO="$notes_repo" "$script" --quiet

[[ $(git -C "$dots_repo" rev-list --count '@{u}..') -eq 0 ]]
[[ $(git -C "$notes_repo" rev-list --count '@{u}..') -eq 0 ]]

# Missing repositories are intentionally harmless for a portable shell setup.
DOTS_REPO="$tmpdir/missing-dots" NOTES_REPO="$tmpdir/missing-notes" "$script" --quiet
