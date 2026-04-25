#!/usr/bin/env bash

if [[ -n "${GLOW_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

glow_repo="$DEV_REPOS/glow"
glow_remote="https://github.com/charmbracelet/glow.git"
glow_bin="/usr/local/bin/glow"

if [[ -z "${GO_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/go.sh
  source "$script_dir/go.sh"
fi

mkdir -p "$DEV_REPOS"

if [[ ! -d "$glow_repo/.git" ]]; then
  git clone -q "$glow_remote" "$glow_repo"
else
  git -C "$glow_repo" fetch -q
  git -C "$glow_repo" pull -q --ff-only
fi

tmp_gobin=$(mktemp -d) || fatal "Failed to create temp GOBIN for glow"
(
  cd "$glow_repo" || exit 1
  GOBIN="$tmp_gobin" go install .
) || {
  rm -rf "$tmp_gobin"
  fatal "Failed to install glow"
}
if ! "${SUDO[@]}" install -m 0755 "$tmp_gobin/glow" "$glow_bin"; then
  rm -rf "$tmp_gobin"
  fatal "Failed to install glow binary to $glow_bin"
fi
rm -rf "$tmp_gobin"

case "$PLATFORM" in
  Darwin)
    glow_config_dir="$HOME/Library/Preferences/glow"
    ;;
  *)
    glow_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/glow"
    ;;
esac
export GLOW_CONFIG_DIR="$glow_config_dir"
mkdir -p "$glow_config_dir"

eval_template "$DOTS_REPO/templates/glow/glow.yml" "$glow_config_dir/glow.yml"
eval_template "$DOTS_REPO/templates/glow/solarized-light.json" "$glow_config_dir/solarized-light.json"
eval_template "$DOTS_REPO/templates/glow/solarized-dark.json" "$glow_config_dir/solarized-dark.json"

export GLOW_SETUP_COMPLETE=1
