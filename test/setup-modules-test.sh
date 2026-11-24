#!/usr/bin/env bash
# Module selection through setup.sh and argument forwarding through bootstrap.sh.

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

home="$tmpdir/home"
mkdir -p "$home"

dry_run() {
  env -i HOME="$home" PATH="$PATH" DOTS_REPO="$repo_root" HAS_JAMF=0 \
    DOTS_MACHINE_ENV_FILE="$tmpdir/none" "$@" 2>&1 | grep -E '^(Would run|Error)'
}

full='Would run setup modules: http aws vim tmux zsh llm rbenv go tmuxinator glow ghostty akagent'

# Module selection is independent of machine class.
[[ "$(dry_run MACHINE_CLASS=personal bash "$repo_root/setup.sh" --dry-run)" == "$full" ]]
[[ "$(dry_run MACHINE_CLASS=work bash "$repo_root/setup.sh" --dry-run)" == "$full" ]]
[[ "$(dry_run MACHINE_CLASS=personal bash "$repo_root/setup.sh" --dry-run --only llm,go,akagent)" == 'Would run setup modules: llm go akagent' ]]

# Unknown modules are rejected.
if dry_run bash "$repo_root/setup.sh" --dry-run --only nope >/dev/null; then exit 1; fi

# The generated bootstrap forwards its arguments to setup.sh.
rg -q '\./setup\.sh "\$@"\)$' "$repo_root/bootstrap.sh"
