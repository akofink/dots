#!/usr/bin/env bash

if [ ! $REPOS_SETUP_COMPLETE ]; then
  source setup/repos.sh
fi

eval_template "$DOTS_REPO/templates/.vimrc" "$HOME/.vimrc"

if [ ! -d ~/dev/repos/vim ]; then
  mkdir -p ~/dev/repos
  git clone https://github.com/vim/vim.git ~/dev/repos/vim
fi

(cd ~/dev/repos/vim && git pull)

${PKG_INSTALL[@]} ${VIM_BUILD_DEPS[@]}

if ! which vim; then
  (
    cd ~/dev/repos/vim;
    make && $SUDO make install
  )
fi

if [ ! -f ~/.vim/autoload/plug.vim ]; then
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi
