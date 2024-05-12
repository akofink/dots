#!/usr/bin/env bash

export DEV_REPOS=${DEV_REPOS:-"$HOME/dev/repos"}
export DOTS_REPO="$DEV_REPOS/dots"
export GITHUB_TOKEN=${GITHUB_TOKEN:-"''"}

source "$DOTS_REPO/setup/util.sh" # eval_template

eval_template "$DOTS_REPO/templates/.vimrc" "$HOME/.vimrc"

if [ ! -d ~/dev/repos/vim ]; then
  mkdir -p ~/dev/repos
  git clone https://github.com/vim/vim.git ~/dev/repos/vim
fi

if ! which vim; then
  (
    cd ~/dev/repos/vim;
    make && sudo make install
  )
fi

if [ ! -f ~/.vim/autoload/plug.vim ]; then
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi
