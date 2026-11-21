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

install_aka_link() {
  local aka_link="$akagent_bin_dir/aka"
  local current_target
  local tmp_link

  if [[ -L "$aka_link" ]]; then
    current_target=$(readlink "$aka_link") || fatal "Failed to read symlink $aka_link"
    if [[ "$current_target" == "akagent" ]]; then
      return
    fi
    if [[ "$current_target" != "$akagent_bin_dir/akagent" ]]; then
      fatal "Refusing to replace unrelated symlink at $aka_link"
    fi
  elif [[ -e "$aka_link" ]]; then
    fatal "Refusing to replace unrelated file at $aka_link"
  fi

  tmp_link="$akagent_bin_dir/.aka-install.$$"
  if ! ln -s akagent "$tmp_link" || ! mv -f "$tmp_link" "$aka_link"; then
    rm -f "$tmp_link"
    fatal "Failed to install aka at $aka_link"
  fi
}

mkdir -p "$DEV_REPOS"
if [[ ! -d "$akagent_repo/.git" ]]; then
  git clone -q "$akagent_remote" "$akagent_repo" || fatal "Failed to clone akagent"
else
  if [[ -n "$(git -C "$akagent_repo" status --porcelain)" ]]; then
    fatal "Refusing to update dirty akagent checkout at $akagent_repo"
  fi
  if [[ "$(git -C "$akagent_repo" branch --show-current)" != "main" ]]; then
    fatal "Refusing to update akagent checkout not on main at $akagent_repo"
  fi
  git -C "$akagent_repo" fetch -q origin || fatal "Failed to fetch akagent"
  git -C "$akagent_repo" merge -q --ff-only origin/main || fatal "Failed to fast-forward akagent main to origin/main"
fi

mkdir -p "$akagent_bin_dir"
akagent_bin="$akagent_bin_dir/akagent"

# Bootstrap with one plain build only when no binary exists yet; every later run
# uses the supported `akagent update`, which embeds build_revision.
if [[ ! -x "$akagent_bin" ]]; then
  tmp_install="$akagent_bin_dir/.akagent-install.$$"
  if ! (cd "$akagent_repo" && go build -o "$tmp_install" ./cmd/akagent) || ! mv -f "$tmp_install" "$akagent_bin"; then
    rm -f "$tmp_install"
    fatal "Failed to bootstrap akagent at $akagent_bin"
  fi
fi

if ! update_output=$("$akagent_bin" update --source "$akagent_repo" 2>&1); then
  printf '%s\n' "$update_output" >&2
  fatal "akagent update failed"
fi
if [[ "$update_output" == *"source_changed: true"* ]]; then
  printf '%s\n' "$update_output"
fi
install_aka_link

export AKAGENT_SETUP_COMPLETE=1
