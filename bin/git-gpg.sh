#!/usr/bin/env bash

if [[ -t 2 ]]; then
  exec gpg "$@"
fi

exec gpg --batch --pinentry-mode error "$@"
