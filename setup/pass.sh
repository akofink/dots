#!/usr/bin/env bash

export PASS_GPG_KEY=${PASS_GPG_KEY:-"A412F50"}
export PASS_REPO_COMMITS=$(pass git log --oneline | wc -l)

if [ ! $PASS_REPO_COMMITS -gt 1 ]; then
  pass init $PASS_GPG_KEY
  pass git init
  pass git remote add origin https://github.com/akofink/pass.git
  pass git reset --hard origin/main
fi
