#!/usr/bin/env bash

DEV_REPOS=${DEV_REPOS:-"~/dev/repos"}
GIT_EMAIL=${GIT_EMAIL:-"ajkofink@gmail.com"}
GIT_SIGNINGKEY=${GIT_SIGNINGKEY:-"2C911B0A"}
GITHUB_USER=${GITHUB_USER:-"akofink"}

source "$DEV_REPOS/util.sh"

eval_template "templates/.gitignore" "~/.gitignore"
eval_template "templates/.gitconfig" "~/.gitconfig"
