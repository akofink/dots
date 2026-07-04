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

merge_directory_contents_no_overwrite() {
  local source_dir="$1"
  local destination_dir="$2"

  mkdir -p "$destination_dir"

  local entry relative_path destination_path
  shopt -s dotglob nullglob
  for entry in "$source_dir"/*; do
    relative_path=${entry#"$source_dir"/}
    destination_path="$destination_dir/$relative_path"

    if [[ -e "$destination_path" || -L "$destination_path" ]]; then
      if [[ -d "$entry" && ! -L "$entry" && -d "$destination_path" && ! -L "$destination_path" ]]; then
        merge_directory_contents_no_overwrite "$entry" "$destination_path"
      elif [[ -f "$entry" && -f "$destination_path" ]] && cmp -s "$entry" "$destination_path"; then
        continue
      elif [[ -L "$entry" && -L "$destination_path" ]] && [[ "$(readlink "$entry")" == "$(readlink "$destination_path")" ]]; then
        continue
      else
        fatal "Refusing to overwrite different existing firstmate state: $destination_path"
      fi
    else
      cp -a "$entry" "$destination_dir/"
    fi
  done
  shopt -u dotglob nullglob
}

install_firstmate_state_symlink() {
  local name="$1"
  local local_path="$firstmate_repo/$name"
  local notes_path="$firstmate_state_root/$name"

  mkdir -p "$notes_path"

  if [[ -L "$local_path" ]]; then
    local current_target
    current_target=$(readlink "$local_path") || fatal "Failed to read symlink $local_path"
    if [[ "$current_target" == "$notes_path" ]]; then
      return
    fi
    fatal "Refusing to replace existing firstmate $name symlink: $local_path -> $current_target"
  fi

  if [[ -e "$local_path" ]]; then
    if [[ ! -d "$local_path" ]]; then
      fatal "Refusing to replace non-directory firstmate state path: $local_path"
    fi

    merge_directory_contents_no_overwrite "$local_path" "$notes_path"

    local timestamp
    timestamp=$(date +%y%m%d%H%M%S) || fatal "Failed to generate backup timestamp"
    mv "$local_path" "$local_path.migrated.$timestamp"
  fi

  ln -s "$notes_path" "$local_path"
}

if [[ ! -d "$firstmate_repo/.git" ]]; then
  mkdir -p "$(dirname -- "$firstmate_repo")"
  git clone "https://github.com/kunchenguid/firstmate.git" "$firstmate_repo"
fi

if [[ ! -d "$NOTES_REPO/.git" ]]; then
  fatal "Missing notes repo at $NOTES_REPO; run setup/repos.sh first"
fi

install_firstmate_state_symlink data
install_firstmate_state_symlink config

echo "Leaving firstmate volatile state local at $firstmate_repo/state"

export FIRSTMATE_SETUP_COMPLETE=1
