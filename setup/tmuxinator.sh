#!/usr/bin/env bash

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${REPOS_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/repos.sh
  source "$script_dir/repos.sh"
fi

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
