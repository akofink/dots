#!/usr/bin/env bash

export PASS_GPG_KEY=${PASS_GPG_KEY:-"A412F50"}

if [ ! -d ~/.password-store ]; then
  pass init $PASS_GPG_KEY
  pass git init
  pass git remote add origin https://github.com/akofink/pass.git
  pass git fetch origin
  pass git reset --hard origin/main
fi
