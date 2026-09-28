#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

home="$test_root/home"
nvm_dir="$home/.nvm"
mkdir -p \
  "$nvm_dir/alias/lts" \
  "$nvm_dir/versions/node/v12.22.12/bin" \
  "$nvm_dir/versions/node/v24.14.1/bin"
printf 'lts/*\n' > "$nvm_dir/alias/default"
printf 'lts/krypton\n' > "$nvm_dir/alias/lts/*"
printf 'v24.15.0\n' > "$nvm_dir/alias/lts/krypton"

zsh_bin=$(command -v zsh)
node_bin=$(env -i \
  HOME="$home" \
  NVM_DIR="$nvm_dir" \
  PATH="/usr/bin:/bin" \
  "$zsh_bin" -dfc 'source "$1/templates/.zshenv"; print -r -- $path[1]' zsh "$repo_root")
[[ "$node_bin" == "$nvm_dir/versions/node/v24.14.1/bin" ]]

printf 'zshenv-nvm-default-test: ok\n'
