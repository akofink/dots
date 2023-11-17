#!/usr/bin/env bash

export DEV_REPOS=${DEV_REPOS:-"$HOME/dev/repos"}
export DOTS_REPO="$DEV_REPOS/dots"
export GITHUB_TOKEN=${GITHUB_TOKEN:-"''"}

source "$DOTS_REPO/util.sh" # eval_template

eval_template "$DOTS_REPO/templates/.vimrc" "$HOME/.vimrc"

if [ ! -f ~/.vim/autoload/plug.vim ]; then
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi
