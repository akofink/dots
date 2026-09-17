#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
matches=$(
  grep -RIn --exclude-dir=.git \
    -e 'acli' \
    "$repo_root/setup" \
    "$repo_root/templates" \
    "$repo_root/bin" || true
)

if [[ -n "$matches" ]]; then
  printf 'acli must not appear in setup, templates, or bin:\n%s\n' "$matches" >&2
  exit 1
fi

printf 'tmuxinator-acli-test: ok\n'
