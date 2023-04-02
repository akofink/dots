#!/usr/bin/env bash

DEV_REPOS=${DEV_REPOS:-"$HOME/dev/repos"}
DOTS_REPO="$DEV_REPOS/dots"
GIT_EMAIL=${GIT_EMAIL:-"ajkofink@gmail.com"}
GIT_SIGNINGKEY=${GIT_SIGNINGKEY:-"2C911B0A"}
GITHUB_USER=${GITHUB_USER:-"akofink"}

source "$DOTS_REPO/util.sh"

eval_template "templates/.gitignore" "~/.gitignore"
eval_template "templates/.gitconfig" "~/.gitconfig"
