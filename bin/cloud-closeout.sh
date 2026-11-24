#!/usr/bin/env bash
# Cloud-session closeout: leave each attached repo on a local main equal to origin/main.
# The harness checks repos out on a claude/<slug> branch, but cloud work is delivered
# straight to main, so that branch ends up fully merged and only triggers "unpushed
# commits" warnings. For each repo: fetch, then
#   - dirty tree or in-progress merge/rebase: report, change nothing
#   - local main ahead of or diverged from origin/main: report (unpushed work), change nothing
#   - current branch not merged into origin/main: report, change nothing
#   - otherwise: fast-forward main, check it out, delete the merged branch (git branch -d)
# Exit 0 when every repo is clean on main; exit 1 when anything needs attention.
# Usage: cloud-closeout.sh [--check] [attach-root]   (--check reports without changing; default root /home/user)
set -uo pipefail

check=0
if [[ "${1:-}" == "--check" ]]; then check=1; shift; fi
attach_root=${1:-/home/user}
status=0

note() { printf '%s: %s\n' "$name" "$*"; }
attention() { note "$*"; status=1; }

for dir in "$attach_root"/*/; do
  [[ -e "$dir/.git" ]] || continue
  name=$(basename "$dir")
  git_dir=$(git -C "$dir" rev-parse --git-dir) || { attention "not a usable git repo"; continue; }
  [[ "$git_dir" == /* ]] || git_dir="$dir/$git_dir"
  if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then attention "dirty working tree; left alone"; continue; fi
  if [[ -e "$git_dir/MERGE_HEAD" || -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
    attention "merge or rebase in progress; left alone"; continue
  fi
  git -C "$dir" fetch -q origin || { attention "fetch failed"; continue; }
  if ! git -C "$dir" rev-parse -q --verify origin/main >/dev/null; then attention "no origin/main"; continue; fi
  current=$(git -C "$dir" branch --show-current)
  if git -C "$dir" rev-parse -q --verify refs/heads/main >/dev/null; then
    if ! git -C "$dir" merge-base --is-ancestor main origin/main; then
      attention "local main has commits not on origin/main (unpushed work); push with git push origin main or report"; continue
    fi
  fi
  if [[ -n "$current" && "$current" != main ]] && ! git -C "$dir" merge-base --is-ancestor HEAD origin/main; then
    attention "branch $current has commits not in origin/main; deliver them to main first"; continue
  fi
  if [[ "$check" -eq 1 ]]; then
    if [[ "$current" == main ]] && [[ "$(git -C "$dir" rev-parse HEAD)" == "$(git -C "$dir" rev-parse origin/main)" ]]; then
      note "ok (main at origin/main)"
    else
      attention "needs closeout (on ${current:-detached HEAD}); run without --check"
    fi
    continue
  fi
  if git -C "$dir" rev-parse -q --verify refs/heads/main >/dev/null; then
    git -C "$dir" checkout -q main && git -C "$dir" merge -q --ff-only origin/main || { attention "could not fast-forward main"; continue; }
  else
    git -C "$dir" checkout -q -b main --track origin/main || { attention "could not create main"; continue; }
  fi
  if [[ -n "$current" && "$current" != main ]]; then
    if git -C "$dir" branch -q -d "$current" 2>/dev/null; then
      note "on main at $(git -C "$dir" rev-parse --short HEAD); deleted merged branch $current"
    else
      attention "on main, but could not delete $current (checked out in another worktree?)"
      continue
    fi
  else
    note "on main at $(git -C "$dir" rev-parse --short HEAD)"
  fi
done
exit "$status"
