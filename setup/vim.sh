#!/usr/bin/env bash

export DEV_REPOS=${DEV_REPOS:-"$HOME/dev/repos"}
export DOTS_REPO="$DEV_REPOS/dots"

source "$DOTS_REPO/util.sh" # eval_template

eval_template "$DOTS_REPO/templates/.vimrc" "$HOME/.vimrc"
