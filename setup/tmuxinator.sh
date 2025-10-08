#!/usr/bin/env bash

if ! command -v tmuxinator &> /dev/null
then
  gem install tmuxinator
fi

if [ ! -d "$HOME/.config" ]; then
  mkdir -p "$HOME/.config"
fi

if [ ! -h "$HOME/.config/tmuxinator" ]; then
  if [ -d "$HOME/.config/tmuxinator" ]; then
    timestamp="$(date +"%Y%m%dT%H%M%S")"
    mv "$HOME/.config/tmuxinator" "$HOME/.config/tmuxinator.old.$timestamp"
  fi

  ln -s "$DOTS_REPO/templates/tmuxinator" "$HOME/.config/tmuxinator"
fi
