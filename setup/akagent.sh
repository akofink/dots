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

akagent_version="${AKAGENT_VERSION:-latest}"
akagent_bin_dir="$HOME/.local/bin"
tmp_gobin=$(mktemp -d) || fatal "Failed to create temp GOBIN for akagent"

if ! GOBIN="$tmp_gobin" go install "github.com/akofink/akagent-cli/cmd/akagent@$akagent_version"; then
  rm -rf "$tmp_gobin"
  fatal "Failed to build akagent version $akagent_version"
fi

mkdir -p "$akagent_bin_dir"
if ! install -m 0755 "$tmp_gobin/akagent" "$akagent_bin_dir/akagent"; then
  rm -rf "$tmp_gobin"
  fatal "Failed to install akagent to $akagent_bin_dir/akagent"
fi
rm -rf "$tmp_gobin"

export AKAGENT_SETUP_COMPLETE=1
