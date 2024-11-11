#!/usr/bin/env bash

if [ ! -d ~/.rbenv ]; then
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv
fi

PATH=$PATH:~/.rbenv/bin

if [ ! -d "$(rbenv root)"/plugins/ruby-build ]; then
  git clone https://github.com/rbenv/ruby-build.git "$(rbenv root)"/plugins/ruby-build
fi

LATEST_RUBY_VERSION=$(rbenv install -l | grep -v - | tail -1)

rbenv install $LATEST_RUBY_VERSION \
  && rbenv global $LATEST_RUBY_VERSION
