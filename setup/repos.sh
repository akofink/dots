#!/usr/bin/env bash

if [[ -n "${REPOS_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${GIT_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/git.sh
  source "$script_dir/git.sh"
fi

mkdir -p "$DEV_REPOS"

if [[ ! -d "$DOTS_REPO" ]]
then
  git clone https://github.com/akofink/dots.git "$DOTS_REPO"
fi

eval_template "$DOTS_REPO/templates/gitignore.template" "$HOME/.gitignore"
eval_template "$DOTS_REPO/templates/.gitconfig" "$HOME/.gitconfig"

export REPOS_SETUP_COMPLETE=1
