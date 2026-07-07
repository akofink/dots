#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$repo_root/bin/dots-backups.sh"

tmp_root=$(mktemp -d)
tmp_root=$(cd -- "$tmp_root" && pwd -P)
cleanup() {
  rm -rf "$tmp_root"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_exists() {
  [[ -e "$1" || -L "$1" ]] || fail "expected $1 to exist"
}

assert_missing() {
  [[ ! -e "$1" && ! -L "$1" ]] || fail "expected $1 to be removed"
}

home_one="$tmp_root/home-one"
mkdir -p "$home_one/.config/opencode" "$home_one/.agents"
printf 'current\n' > "$home_one/.zshrc"
printf 'current\n' > "$home_one/.zshrc.old.240101000000"
printf 'current\n' > "$home_one/.zshrc.old.240102000000"
printf 'config\n' > "$home_one/.config/opencode/opencode.jsonc"
printf 'config\n' > "$home_one/.config/opencode/opencode.jsonc.old.240101000000"
printf 'config\n' > "$home_one/.config/opencode/opencode.jsonc.old.240102000000"
printf 'agents\n' > "$home_one/.agents/AGENTS.md"
printf 'agents\n' > "$home_one/.agents/AGENTS.md.old.240101000000"
printf 'agents\n' > "$home_one/.agents/AGENTS.md.old.240102000000"
printf 'private\n' > "$home_one/private.old.240101000000"
printf 'private\n' > "$home_one/.config/private.old.240101000000"

audit_output=$(HOME="$home_one" "$script" --root "$home_one")
[[ "$audit_output" == *"WOULD DELETE $home_one/.zshrc.old.240101000000"* ]] || fail "audit did not report older redundant backup"
[[ "$audit_output" == *"KEEP newest: $home_one/.zshrc.old.240102000000"* ]] || fail "audit did not preserve newest backup"
[[ "$audit_output" != *"private.old"* ]] || fail "audit reported an unrelated backup"

config_output=$(HOME="$home_one" "$script" --root "$home_one/.config")
[[ "$config_output" == *"WOULD DELETE $home_one/.config/opencode/opencode.jsonc.old.240101000000"* ]] || fail "scoped .config audit did not report known backup"
[[ "$config_output" != *".zshrc.old"* ]] || fail "scoped .config audit reported top-level backup"
[[ "$config_output" != *"private.old"* ]] || fail "scoped .config audit reported unrelated backup"

agents_output=$(HOME="$home_one" "$script" --root "$home_one/.agents")
[[ "$agents_output" == *"WOULD DELETE $home_one/.agents/AGENTS.md.old.240101000000"* ]] || fail "scoped .agents audit did not report known backup"
[[ "$agents_output" != *".zshrc.old"* ]] || fail "scoped .agents audit reported top-level backup"

home_two="$tmp_root/home-two"
mkdir -p "$home_two"
printf 'current\n' > "$home_two/.zshrc"
printf 'current\n' > "$home_two/.zshrc.old.240102000000"
HOME="$home_two" "$script" --root "$home_two" --prune --delete-newest >/dev/null
assert_missing "$home_two/.zshrc.old.240102000000"
assert_exists "$home_two/.zshrc"

home_three="$tmp_root/home-three"
mkdir -p "$home_three"
printf 'unique\n' > "$home_three/.zshrc.old.240102000000"
printf 'private\n' > "$home_three/private.old.240102000000"
HOME="$home_three" "$script" --root "$home_three" --prune --all >/dev/null
assert_missing "$home_three/.zshrc.old.240102000000"
assert_exists "$home_three/private.old.240102000000"

printf 'dots-backups-test: ok\n'
