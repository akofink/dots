#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
primary="$tmp/primary"
worktree="$tmp/worktree"
home="$tmp/home"
mkdir -p "$primary" "$worktree" "$home"
git -C "$primary" init -q
git -C "$worktree" init -q
printf 'preserve-me\n' > "$home/.gitconfig"

output=$(HOME="$home" DEV_REPOS="$tmp" DOTS_PRIMARY_REPO="$primary" DOTS_REPO="$worktree" \
  GIT_SETUP_COMPLETE=1 bash -c 'source "$1/setup/repos.sh"' _ "$repo_root" 2>&1) && {
  echo "expected worktree setup to be refused" >&2
  exit 1
}
[[ "$output" == *"Refusing to render machine config"* ]]
[[ "$output" == *"primary dots clone"* ]]
[[ "$(<"$home/.gitconfig")" == "preserve-me" ]]
printf 'setup/repos.sh refuses non-primary checkouts before rendering machine config\n'
