#!/usr/bin/env bash

if [[ -n "${OPENCODE_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

opencode_install_dir="$HOME/.opencode/bin"
legacy_opencode_bin="/usr/local/bin/opencode"

# opencode config linking (handled by llm.sh) should proceed even when the CLI
# install is skipped or fails, so treat every install failure as a warning that
# returns without setting the completion guard.
if command -v opencode >/dev/null 2>&1; then
  echo "opencode already installed; skipping."
  export OPENCODE_SETUP_COMPLETE=1
  return 0
fi

if ! command -v curl >/dev/null 2>&1; then
  warn "curl not found; skipping opencode install"
  return 1
fi

if ! opencode_install_script=$(mktemp); then
  warn "Failed to create temp file for opencode installer; skipping"
  return 1
fi
cleanup_opencode_install_script() {
  rm -f "$opencode_install_script"
}
trap cleanup_opencode_install_script RETURN

if ! curl -fsSL https://opencode.ai/install -o "$opencode_install_script"; then
  warn "Failed to download opencode installer; skipping"
  return 1
fi
if ! bash "$opencode_install_script" --no-modify-path; then
  warn "Failed to run opencode installer; skipping"
  return 1
fi

export PATH="$opencode_install_dir:$PATH"

if [[ -x "$opencode_install_dir/opencode" && -f "$legacy_opencode_bin" ]] && grep -q 'OPENCODE_CUSTOM_BRANCH' "$legacy_opencode_bin"; then
  "${SUDO[@]}" rm -f "$legacy_opencode_bin"
fi

if ! command -v opencode >/dev/null 2>&1; then
  warn "opencode installer completed but no opencode executable is available on PATH; skipping"
  return 1
fi
export OPENCODE_SETUP_COMPLETE=1
