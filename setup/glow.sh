#!/usr/bin/env bash

if [[ -n "${GLOW_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

if [[ "$PLATFORM" != "Darwin" ]]; then
  echo "Skipping Glow setup on $PLATFORM"
  export GLOW_SETUP_COMPLETE=1
  return
fi

glow_config_dir="$HOME/Library/Preferences/glow"
mkdir -p "$glow_config_dir"

eval_template "$DOTS_REPO/templates/glow/glow.yml" "$glow_config_dir/glow.yml"
eval_template "$DOTS_REPO/templates/glow/solarized-light.json" "$glow_config_dir/solarized-light.json"
eval_template "$DOTS_REPO/templates/glow/solarized-dark.json" "$glow_config_dir/solarized-dark.json"

export GLOW_SETUP_COMPLETE=1
