#!/usr/bin/env bash

if [[ -n "${GO_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

export GOENV_ROOT="${GOENV_ROOT:-$HOME/.goenv}"

if [[ ! -d "$GOENV_ROOT/.git" ]]; then
  git clone -q https://github.com/go-nv/goenv.git "$GOENV_ROOT"
else
  git -C "$GOENV_ROOT" pull -q --ff-only
fi

export PATH="$GOENV_ROOT/bin:$PATH"
eval "$(goenv init -)"

latest_go_version=$(goenv install -l | grep -E '^[[:space:]]*[0-9]+\.[0-9]+\.[0-9]+$' | tail -1 | tr -d '[:space:]')
if [[ -z "$latest_go_version" ]]; then
  fatal "Failed to determine latest Go version"
fi

goenv install -s "$latest_go_version"
goenv global "$latest_go_version"

if ! command -v go >/dev/null 2>&1; then
  fatal "go not found after installation"
fi

mkdir -p "$HOME/go/bin"
export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$GOPATH/bin:$PATH"

export GO_SETUP_COMPLETE=1
