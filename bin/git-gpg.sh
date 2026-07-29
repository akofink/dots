#!/usr/bin/env bash

if { : >/dev/tty; } 2>/dev/null; then
  exec gpg "$@"
fi

exec gpg --batch --pinentry-mode error "$@"
