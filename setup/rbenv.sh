#!/usr/bin/env bash

if [[ -z "${REPOS_SETUP_COMPLETE:-}" ]]; then
  source setup/repos.sh
fi

if [[ ! -z "${RUBY_BUILD_DEPS[@]}" ]]; then
  "${PKG_INSTALL[@]}" "${RUBY_BUILD_DEPS[@]}"
fi

if [ ! -d ~/.rbenv ]; then
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv
fi
(cd ~/.rbenv && git pull -q)

PATH=$PATH:~/.rbenv/bin

if [ ! -d "$(rbenv root)"/plugins/ruby-build ]; then
  git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
fi

(cd "$(rbenv root)/plugins/ruby-build" && git pull -q)

LATEST_RUBY_VERSION=$(rbenv install -l | grep -v - | tail -1)

rbenv install -s $LATEST_RUBY_VERSION \
  && rbenv global $LATEST_RUBY_VERSION
