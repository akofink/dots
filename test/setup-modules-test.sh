#!/usr/bin/env bash
# Module selection: --only, DOTS_SETUP_ONLY, and the MACHINE_CLASS=agent default.

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

home="$tmpdir/home"
mkdir -p "$home"

dry_run() {
  env -i HOME="$home" PATH="$PATH" DOTS_REPO="$repo_root" HAS_JAMF=0 \
    DOTS_MACHINE_ENV_FILE="$tmpdir/none" "$@" \
    bash "$repo_root/setup.sh" --dry-run 2>&1 | grep -E '^(Would run|Error)'
}

full='Would run setup modules: http aws vim tmux zsh llm opencode rbenv go tmuxinator glow ghostty akagent'
agent='Would run setup modules: llm go akagent'

[[ "$(dry_run MACHINE_CLASS=personal)" == "$full" ]]
[[ "$(dry_run MACHINE_CLASS=work)" == "$full" ]]
[[ "$(dry_run MACHINE_CLASS=agent)" == "$agent" ]]

# DOTS_SETUP_ONLY overrides the class default; --only overrides both.
[[ "$(dry_run MACHINE_CLASS=agent DOTS_SETUP_ONLY=tmux,zsh)" == 'Would run setup modules: tmux zsh' ]]
only_output=$(env -i HOME="$home" PATH="$PATH" DOTS_REPO="$repo_root" MACHINE_CLASS=agent DOTS_SETUP_ONLY=tmux \
  bash "$repo_root/setup.sh" --dry-run --only glow 2>&1 | grep '^Would run')
[[ "$only_output" == 'Would run setup modules: glow' ]]

# Machine class can come from the machine env file.
printf '%s\n' 'export MACHINE_CLASS="${MACHINE_CLASS:-agent}"' > "$tmpdir/machine.env"
[[ "$(dry_run DOTS_MACHINE_ENV_FILE="$tmpdir/machine.env")" == "$agent" ]]

# Unknown modules and unknown classes are rejected.
if dry_run DOTS_SETUP_ONLY=nope >/dev/null; then exit 1; fi
if env -i HOME="$home" PATH="$PATH" DOTS_REPO="$repo_root" MACHINE_CLASS=bogus \
  bash "$repo_root/setup.sh" --dry-run >/dev/null 2>&1; then exit 1; fi
