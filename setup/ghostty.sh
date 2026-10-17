#!/usr/bin/env bash

# Ghostty is intentionally managed only on macOS. Check the OS before reading
# any Ghostty paths, sourcing setup helpers, or invoking a package manager.
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Skipping Ghostty setup: macOS only."
  return 0 2>/dev/null || exit 0
fi

if [[ -n "${GHOSTTY_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

if ! command -v ghostty >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    fatal "Homebrew is required to install Ghostty on macOS."
  fi
  brew install --cask ghostty
fi

mkdir -p "$HOME/.config/ghostty"
eval_template "$DOTS_REPO/templates/ghostty/config" "$HOME/.config/ghostty/config" ''
export GHOSTTY_SETUP_COMPLETE=1
