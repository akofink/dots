#!/usr/bin/env bash

export DEV_REPOS=${DEV_REPOS:-"$HOME/dev/repos"}
export DOTS_REPO="$DEV_REPOS/dots"
export GITHUB_TOKEN=${GITHUB_TOKEN:-"''"}

source "$DOTS_REPO/util.sh" # eval_template

eval_template "$DOTS_REPO/templates/.vimrc" "$HOME/.vimrc"

# Clone Vundle for package management
mkdir -p ~/.vim/bundle
if [ ! -d ~/.vim/bundle/Vundle.vim ]; then
  git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
fi

