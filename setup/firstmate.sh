#!/usr/bin/env bash

if [[ -n "${FIRSTMATE_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

firstmate_repo="${FIRSTMATE_REPO:-"$DEV_REPOS/firstmate"}"
firstmate_state_root="${FIRSTMATE_LOCAL_STATE_DIR:-"$NOTES_REPO/firstmate/local-state"}"

install_firstmate_data_file_symlinks() {
  local notes_data="$firstmate_state_root/data"
  local local_data="$firstmate_repo/data"

  mkdir -p "$notes_data"
  mkdir -p "$local_data"

  shopt -s dotglob nullglob
  for notes_file in "$notes_data"/*; do
    local filename
    filename=$(basename "$notes_file")
    local target="$local_data/$filename"

    if [[ -L "$target" ]]; then
      local current
      current=$(readlink -f "$target") || fatal "Failed to read symlink $target"
      if [[ "$current" == "$notes_file" ]]; then
        continue
      fi
      fatal "Refusing to replace existing firstmate data symlink: $target -> $current"
    fi

    if [[ -e "$target" ]]; then
      if [[ -d "$target" ]]; then
        continue
      fi
      fatal "Refusing to replace existing firstmate data path: $target"
    fi

    ln -s "$notes_file" "$target"
  done
  shopt -u dotglob nullglob
}

if [[ ! -d "$firstmate_repo/.git" ]]; then
  mkdir -p "$(dirname -- "$firstmate_repo")"
  git clone "https://github.com/kunchenguid/firstmate.git" "$firstmate_repo"
fi

if [[ ! -d "$NOTES_REPO/.git" ]]; then
  fatal "Missing notes repo at $NOTES_REPO; run setup/repos.sh first"
fi

install_firstmate_data_file_symlinks

echo "Leaving firstmate volatile state local at $firstmate_repo/state"

export FIRSTMATE_SETUP_COMPLETE=1
