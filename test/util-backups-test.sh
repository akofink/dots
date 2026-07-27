#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

export HOME="$test_root/home"
export DOTS_REPO="$repo_root"
export DOTS_BACKUP_DIR="$test_root/backups"
export ENV_SETUP_COMPLETE=1
mkdir -p "$HOME/.agents/skills/example" "$test_root/source"
printf 'old\n' > "$HOME/.agents/skills/example/SKILL.md"
printf 'new\n' > "$test_root/source/SKILL.md"

# shellcheck source=setup/util.sh
source "$repo_root/setup/util.sh"
install_symlink "$test_root/source" "$HOME/.agents/skills/example"

[[ -L "$HOME/.agents/skills/example" ]]
legacy_backups=("$HOME/.agents/skills/example.old."*)
[[ ${#legacy_backups[@]} -eq 0 ]]

backup_prefix="$DOTS_BACKUP_DIR/${HOME#/}/.agents/skills/example.old."
backup_path=("$backup_prefix"*)
[[ ${#backup_path[@]} -eq 1 ]]
[[ -f "${backup_path[0]}/SKILL.md" ]]

printf 'util-backups-test: ok\n'
