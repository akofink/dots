#!/usr/bin/env bash

if [[ -n "${TMUXINATOR_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${RBENV_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/rbenv.sh
  source "$script_dir/rbenv.sh"
fi

if ! RBENV_VERSION="$RUBY_VERSION" rbenv exec gem list --installed --exact tmuxinator > /dev/null; then
  RBENV_VERSION="$RUBY_VERSION" rbenv exec gem install tmuxinator
fi

if [ ! -d "$HOME/.config" ]; then
  mkdir -p "$HOME/.config"
fi

install_symlink "$DOTS_REPO/templates/tmuxinator" "$HOME/.config/tmuxinator"

export TMUXINATOR_SETUP_COMPLETE=1
