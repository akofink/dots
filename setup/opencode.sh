#!/usr/bin/env bash

if [[ -n "${OPENCODE_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

opencode_repo="$DEV_REPOS/opencode"
opencode_remote_name="akofink"
opencode_remote="https://github.com/akofink/opencode.git"
opencode_upstream_remote_name="upstream"
opencode_upstream_remote="https://github.com/anomalyco/opencode.git"
opencode_branch="customizations"
opencode_bin="/usr/local/bin/opencode"
opencode_template="$DOTS_REPO/templates/bin/opencode"

mkdir -p "$DEV_REPOS"

if [[ ! -d "$opencode_repo/.git" ]]; then
  git clone -q --origin "$opencode_remote_name" --branch "$opencode_branch" "$opencode_remote" "$opencode_repo"
  git -C "$opencode_repo" remote add "$opencode_upstream_remote_name" "$opencode_upstream_remote"
else
  git -C "$opencode_repo" remote set-url "$opencode_remote_name" "$opencode_remote"
  if ! git -C "$opencode_repo" remote get-url "$opencode_upstream_remote_name" >/dev/null 2>&1; then
    git -C "$opencode_repo" remote add "$opencode_upstream_remote_name" "$opencode_upstream_remote"
  else
    git -C "$opencode_repo" remote set-url "$opencode_upstream_remote_name" "$opencode_upstream_remote"
  fi

  git -C "$opencode_repo" checkout -q "$opencode_branch"
fi

if ! command -v bun >/dev/null 2>&1; then
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    # shellcheck disable=SC1091
    had_nounset=0
    case $- in
      *u*) had_nounset=1; set +u ;;
    esac
    source "$NVM_DIR/nvm.sh"
    nvm use --lts >/dev/null
    if [[ "$had_nounset" -eq 1 ]]; then
      set -u
    fi
  fi

  if ! command -v npm >/dev/null 2>&1; then
    fatal "npm not found; install nvm/node before setting up opencode"
  fi

  npm install -g bun
fi

if [[ ! -f "$opencode_bin" ]] || ! cmp -s "$opencode_template" "$opencode_bin"; then
  "${SUDO[@]}" rm -f "$opencode_bin"
  "${SUDO[@]}" install -m 0755 "$opencode_template" "$opencode_bin"
fi

export OPENCODE_SETUP_COMPLETE=1
