#!/usr/bin/env bash

if [[ -n "${REPOS_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${GIT_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/git.sh
  source "$script_dir/git.sh"
fi

primary_repo="${DOTS_PRIMARY_REPO:-$DEV_REPOS/dots}"
if [[ ! -d "$primary_repo/.git" ]]; then
  echo "Refusing to render machine config: primary dots clone not found at $primary_repo" >&2
  exit 1
fi
actual_repo=$(git -C "$DOTS_REPO" rev-parse --show-toplevel 2>/dev/null) || {
  echo "Refusing to render machine config: $DOTS_REPO is not a Git checkout" >&2
  exit 1
}
primary_repo=$(cd -- "$primary_repo" && pwd -P)
actual_repo=$(cd -- "$actual_repo" && pwd -P)
if [[ "$actual_repo" != "$primary_repo" ]]; then
  echo "Refusing to render machine config from $actual_repo; use the primary dots clone at $primary_repo" >&2
  exit 1
fi

mkdir -p "$DEV_REPOS"

if [[ ! -d "$DOTS_REPO" ]]
then
  git clone https://github.com/akofink/dots.git "$DOTS_REPO"
fi

if is_truthy "${SETUP_NOTES_REPO:-1}" && [[ ! -d "$NOTES_REPO" ]]
then
  git clone "$NOTES_REPO_URL" "$NOTES_REPO"
fi

eval_template "$DOTS_REPO/templates/gitignore.template" "$HOME/.gitignore" ''
eval_template "$DOTS_REPO/templates/.gitconfig" "$HOME/.gitconfig"
# shellcheck source=setup/ssh.sh
source "$DOTS_REPO/setup/ssh.sh"

export REPOS_SETUP_COMPLETE=1
