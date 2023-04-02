#!/usr/bin/env bash

export DEV_REPOS=${DEV_REPOS:-"$HOME/dev/repos"}
export DOTS_REPO="$DEV_REPOS/dots"
export GIT_EMAIL=${GIT_EMAIL:-"ajkofink@gmail.com"}
export GIT_SIGNINGKEY=${GIT_SIGNINGKEY:-"2C911B0A"}
export GITHUB_USER=${GITHUB_USER:-"akofink"}

source "$DOTS_REPO/util.sh"

eval_template "$DOTS_REPO/templates/.gitignore" "$HOME/.gitignore"
eval_template "$DOTS_REPO/templates/.gitconfig" "$HOME/.gitconfig"
