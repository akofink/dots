#!/usr/bin/env bash
# Point this dots checkout at the tracked hooks in .githooks so commits and pushes run ShellCheck
# like CI does (worktrees of the checkout share the setting). Installs shellcheck with pip when it
# is missing and pip exists. Idempotent. Usage: install-git-hooks.sh [dots-repo]
set -uo pipefail
repo=${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}
[[ -d "$repo/.githooks" ]] || { echo "install-git-hooks: no .githooks in $repo" >&2; exit 1; }
git -C "$repo" config core.hooksPath .githooks || exit 1
if ! command -v shellcheck >/dev/null 2>&1; then
  if command -v pip >/dev/null 2>&1; then
    pip install -q shellcheck-py >/dev/null 2>&1 || echo 'install-git-hooks: could not install shellcheck-py; pushes will be refused until shellcheck exists' >&2
  else
    echo 'install-git-hooks: shellcheck is missing and pip is unavailable; pushes will be refused until shellcheck exists' >&2
  fi
fi
echo "install-git-hooks: core.hooksPath=.githooks in $repo"
