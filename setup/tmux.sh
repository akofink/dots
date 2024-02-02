#!/usr/bin/env bash

DEV_REPOS=${DEV_REPOS:-"$HOME/dev/repos"}
DOTS_REPO="$DEV_REPOS/dots"

TEMPLATE="$DOTS_REPO/templates/.tmux.conf"
TMUX_CONF="$HOME/.tmux.conf"

if [ ! -h $TMUX_CONF ]; then
  if [ -f $TMUX_CONF ]; then
    mv $TMUX_CONF{,.old.$(date +"%Y%m%dT%H%M%S")}
  fi

  ln -s $TEMPLATE $TMUX_CONF
fi

# Set up TPM
if [ ! -d ~/.tmux/plugins/tpm ]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

(cd ~/.tmux/plugins/tpm && git pull)
