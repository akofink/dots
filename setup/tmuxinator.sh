#!/usr/bin/env bash

if [ ! -h ~/.config/tmuxinator ]; then
  if [ -d "$HOME/.config/tmuxinator" ]; then
    mv $HOME/.config/tmuxinator{,.old.$(date +"%Y%m%dT%H%M%S")}
  fi

  ln -s "$DOTS_REPO/templates/tmuxinator" "$HOME/.config/tmuxinator"
fi
