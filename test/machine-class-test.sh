#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

home="$test_root/home"
machine_env="$home/.config/dots/machine.env"
mkdir -p "$(dirname "$machine_env")"
printf '%s\n' 'export MACHINE_CLASS="${MACHINE_CLASS:-work}"' > "$machine_env"
chmod 600 "$machine_env"

run_env() {
  local expected="$1"
  shift
  local actual
  actual=$(env -i \
    HOME="$home" \
    PATH="/usr/bin:/bin" \
    DOTS_REPO="$repo_root" \
    DOTS_MACHINE_ENV_FILE="$machine_env" \
    DOTS_SETUP_ENV_ONLY=1 \
    HAS_JAMF=0 \
    "$@" \
    bash -c 'source "$DOTS_REPO/setup/util.sh" >/dev/null; printf "%s" "$MACHINE_CLASS"')
  [[ "$actual" == "$expected" ]]
}

run_env work
run_env personal MACHINE_CLASS=personal

rm "$machine_env"
run_env personal

mkdir -p "$(dirname "$machine_env")"
printf '%s\n' 'export MACHINE_CLASS="${MACHINE_CLASS:-work}"' > "$machine_env"
zsh_bin=$(command -v zsh)
zsh_value=$(env -i \
  HOME="$home" \
  PATH="/usr/bin:/bin" \
  DOTS_MACHINE_ENV_FILE="$machine_env" \
  "$zsh_bin" -dfc 'source "$1/templates/.zshenv"; print -r -- "$MACHINE_CLASS"' zsh "$repo_root")
[[ "$zsh_value" == work ]]

zsh_value=$(env -i \
  HOME="$home" \
  PATH="/usr/bin:/bin" \
  DOTS_MACHINE_ENV_FILE="$machine_env" \
  MACHINE_CLASS=personal \
  "$zsh_bin" -dfc 'source "$1/templates/.zshenv"; print -r -- "$MACHINE_CLASS"' zsh "$repo_root")
[[ "$zsh_value" == personal ]]

rm -f "$machine_env"
zsh_value=$(env -i \
  HOME="$home" \
  PATH="/usr/bin:/bin" \
  "$zsh_bin" -dfc 'source "$1/templates/.zshenv"; print -r -- "$MACHINE_CLASS"' zsh "$repo_root")
[[ "$zsh_value" == personal ]]

printf 'machine-class-test: ok\n'
