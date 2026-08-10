#!/usr/bin/env bash

if [[ -n "${AKAGENT_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

if [[ -z "${GO_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/go.sh
  source "$script_dir/go.sh"
fi

akagent_repo="$DEV_REPOS/akagent-cli"
akagent_remote="https://github.com/akofink/akagent-cli.git"
akagent_bin_dir="$HOME/.local/bin"
tmp_build_dir=$(mktemp -d) || fatal "Failed to create temporary build directory for akagent"

mkdir -p "$DEV_REPOS"
if [[ ! -d "$akagent_repo/.git" ]]; then
  git clone -q "$akagent_remote" "$akagent_repo" || {
    rm -rf "$tmp_build_dir"
    fatal "Failed to clone akagent"
  }
else
  if [[ -n "$(git -C "$akagent_repo" status --porcelain)" ]]; then
    rm -rf "$tmp_build_dir"
    fatal "Refusing to update dirty akagent checkout at $akagent_repo"
  fi
  if [[ "$(git -C "$akagent_repo" branch --show-current)" != "main" ]]; then
    rm -rf "$tmp_build_dir"
    fatal "Refusing to update akagent checkout not on main at $akagent_repo"
  fi
  git -C "$akagent_repo" fetch -q origin || {
    rm -rf "$tmp_build_dir"
    fatal "Failed to fetch akagent"
  }
  git -C "$akagent_repo" merge -q --ff-only origin/main || {
    rm -rf "$tmp_build_dir"
    fatal "Failed to fast-forward akagent main to origin/main"
  }
fi

if ! (
  cd "$akagent_repo" || exit 1
  go build -o "$tmp_build_dir/akagent" ./cmd/akagent
); then
  rm -rf "$tmp_build_dir"
  fatal "Failed to build akagent"
fi

mkdir -p "$akagent_bin_dir"
tmp_install="$akagent_bin_dir/.akagent-install.$$"
if ! install -m 0755 "$tmp_build_dir/akagent" "$tmp_install" || ! mv -f "$tmp_install" "$akagent_bin_dir/akagent"; then
  rm -f "$tmp_install"
  rm -rf "$tmp_build_dir"
  fatal "Failed to install akagent to $akagent_bin_dir/akagent"
fi
rm -rf "$tmp_build_dir"

export AKAGENT_SETUP_COMPLETE=1
