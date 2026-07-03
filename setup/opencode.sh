#!/usr/bin/env bash

if [[ -n "${OPENCODE_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

if ! command -v curl >/dev/null 2>&1; then
  fatal "curl not found; install curl before setting up opencode"
fi

opencode_install_dir="$HOME/.opencode/bin"
legacy_opencode_bin="/usr/local/bin/opencode"

opencode_install_script=$(mktemp) || fatal "Failed to create temp file for opencode installer"
cleanup_opencode_install_script() {
  rm -f "$opencode_install_script"
}
trap cleanup_opencode_install_script RETURN

if ! curl -fsSL https://opencode.ai/install -o "$opencode_install_script"; then
  fatal "Failed to download opencode installer"
fi
if ! bash "$opencode_install_script" --no-modify-path; then
  fatal "Failed to run opencode installer"
fi

if [[ ! -x "$opencode_install_dir/opencode" ]]; then
  fatal "opencode installer did not create $opencode_install_dir/opencode"
fi

if [[ -f "$legacy_opencode_bin" ]] && grep -q 'OPENCODE_CUSTOM_BRANCH' "$legacy_opencode_bin"; then
  "${SUDO[@]}" rm -f "$legacy_opencode_bin"
fi

export PATH="$opencode_install_dir:$PATH"
export OPENCODE_SETUP_COMPLETE=1
