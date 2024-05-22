#!/usr/bin/env bash

TMUX_VERSION=${TMUX_VERSION:-2.4}

if [ ! $REPOS_SETUP_COMPLETE ]; then
  source setup/repos.sh
fi

${PKG_INSTALL[@]} ${TMUX_BUILD_DEPS[@]}

if [ ! -d ~/dev/repos/tmux ]; then
  mkdir -p ~/dev/repos
  git clone https://github.com/tmux/tmux.git ~/dev/repos/tmux
else
  cd ~/dev/repos/tmux
  git fetch
fi

CONFIGURE_ARGS=()
if ! which tmux; then
  if [[ "$PLATFORM" == "Darwin" ]]; then
    ${PKG_INSTALL[@]} tmux
  else
    (
      cd ~/dev/repos/tmux
      git checkout $TMUX_VERSION
      bash autogen.sh
      echo bash ./configure ${CONFIGURE_ARGS[@]}
      bash ./configure ${CONFIGURE_ARGS[@]}
      make
      $SUDO make install
    )
  fi
fi

eval_template "$DOTS_REPO/templates/.tmux.conf" "$HOME/.tmux.conf"

# Set up TPM
if [ ! -d ~/.tmux/plugins/tpm ]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

(cd ~/.tmux/plugins/tpm && git pull)
