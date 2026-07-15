#!/usr/bin/env bash

if [[ -n "${RBENV_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export RUBY_VERSION="${RUBY_VERSION:-4.0.6}"

if [[ -z "${REPOS_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/repos.sh
  source "$script_dir/repos.sh"
fi

if [[ ${#RUBY_BUILD_DEPS[@]} -gt 0 ]]; then
  "${PKG_INSTALL[@]}" "${RUBY_BUILD_DEPS[@]}"
fi

if [ ! -d ~/.rbenv ]; then
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv
fi
(cd ~/.rbenv && git pull -q --ff-only)

PATH=$PATH:~/.rbenv/bin

if [ ! -d "$(rbenv root)"/plugins/ruby-build ]; then
  git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
fi

(cd "$(rbenv root)/plugins/ruby-build" && git pull -q --ff-only)

rbenv install -s "$RUBY_VERSION" \
  && rbenv global "$RUBY_VERSION"

export RBENV_SETUP_COMPLETE=1
