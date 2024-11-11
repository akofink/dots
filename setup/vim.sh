#!/usr/bin/env bash

if [ ! $REPOS_SETUP_COMPLETE ]; then
  source setup/repos.sh
fi

# Copy over config templates (.vimrc + .vim/*)
eval_template "$DOTS_REPO/templates/.vimrc" "$HOME/.vimrc"
[ -d ~/.vim ] || mkdir ~/.vim
for f in $DOTS_REPO/templates/.vim/*; do
  eval_template "$f" "$HOME/.vim/$(basename $f)"
done

# Clone vim upstream
if [ ! -d ~/dev/repos/vim ]; then
  mkdir -p ~/dev/repos
  git clone -q https://github.com/vim/vim.git ~/dev/repos/vim
fi

# Pull latest vim
(cd ~/dev/repos/vim && git pull -q)

# Build vim from source
if ! which vim >/dev/null; then
  (
    ${PKG_INSTALL[@]} ${VIM_BUILD_DEPS[@]}
    cd ~/dev/repos/vim;
    make && $SUDO make install
  )
fi

# Install vim-plug
if [ ! -f ~/.vim/autoload/plug.vim ]; then
  curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi
