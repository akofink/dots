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
backup_root="$tmp_root/dots/.backups"
mkdir -p "$tmp_root/dots" "$home_one/.config/opencode" "$home_one/.agents" "$home_one/.pi/agent"
printf 'current\n' > "$home_one/.zshrc"
printf 'config\n' > "$home_one/.config/opencode/opencode.jsonc"
printf 'agents\n' > "$home_one/.agents/AGENTS.md"
printf 'pi agents\n' > "$home_one/.pi/agent/AGENTS.md"
# Keep recognizing backups made by older dots versions that lived beside the destination.
printf 'current\n' > "$home_one/.zshrc.old.240103000000"
printf 'private\n' > "$home_one/private.old.240101000000"
printf 'private\n' > "$home_one/.config/private.old.240101000000"

write_backup() {
  local destination=$1
  local timestamp=$2
  local contents=$3
  local backup="$backup_root/${destination#/}.old.$timestamp"
  mkdir -p "$(dirname -- "$backup")"
  printf '%s\n' "$contents" > "$backup"
}

write_backup "$home_one/.zshrc" 240101000000 current
write_backup "$home_one/.zshrc" 240102000000 current
write_backup "$home_one/.config/opencode/opencode.jsonc" 240101000000 config
write_backup "$home_one/.config/opencode/opencode.jsonc" 240102000000 config
write_backup "$home_one/.agents/AGENTS.md" 240101000000 agents
write_backup "$home_one/.agents/AGENTS.md" 240102000000 agents
write_backup "$home_one/.pi/agent/AGENTS.md" 240101000000 'pi agents'
write_backup "$home_one/.pi/agent/AGENTS.md" 240102000000 'pi agents'

audit_output=$(HOME="$home_one" DOTS_REPO="$tmp_root/dots" "$script" --root "$home_one")
[[ "$audit_output" == *"WOULD DELETE $backup_root/${home_one#/}/.zshrc.old.240101000000"* ]] || fail "audit did not report older redundant backup"
[[ "$audit_output" == *"WOULD DELETE $backup_root/${home_one#/}/.pi/agent/AGENTS.md.old.240101000000"* ]] || fail "audit did not report current Pi guidance backup"
[[ "$audit_output" == *"KEEP newest: $home_one/.zshrc.old.240103000000"* ]] || fail "audit did not preserve newest legacy backup"
[[ "$audit_output" != *"private.old"* ]] || fail "audit reported an unrelated backup"

config_output=$(HOME="$home_one" DOTS_REPO="$tmp_root/dots" "$script" --root "$home_one/.config")
[[ "$config_output" == *"WOULD DELETE $backup_root/${home_one#/}/.config/opencode/opencode.jsonc.old.240101000000"* ]] || fail "scoped .config audit did not report known backup"
[[ "$config_output" != *".zshrc.old"* ]] || fail "scoped .config audit reported top-level backup"
[[ "$config_output" != *"private.old"* ]] || fail "scoped .config audit reported unrelated backup"

agents_output=$(HOME="$home_one" DOTS_REPO="$tmp_root/dots" "$script" --root "$home_one/.agents")
[[ "$agents_output" == *"WOULD DELETE $backup_root/${home_one#/}/.agents/AGENTS.md.old.240101000000"* ]] || fail "scoped .agents audit did not report known backup"
[[ "$agents_output" != *".zshrc.old"* ]] || fail "scoped .agents audit reported top-level backup"

home_two="$tmp_root/home-two"
mkdir -p "$home_two"
printf 'current\n' > "$home_two/.zshrc"
mkdir -p "$tmp_root/backups-two/$home_two"
printf 'current\n' > "$tmp_root/backups-two/$home_two/.zshrc.old.240102000000"
HOME="$home_two" DOTS_BACKUP_DIR="$tmp_root/backups-two" "$script" --root "$home_two" --prune --delete-newest >/dev/null
assert_missing "$tmp_root/backups-two/$home_two/.zshrc.old.240102000000"
assert_exists "$home_two/.zshrc"

home_three="$tmp_root/home-three"
mkdir -p "$home_three"
mkdir -p "$tmp_root/backups-three/$home_three"
printf 'unique\n' > "$tmp_root/backups-three/$home_three/.zshrc.old.240102000000"
printf 'private\n' > "$home_three/private.old.240102000000"
HOME="$home_three" DOTS_BACKUP_DIR="$tmp_root/backups-three" "$script" --root "$home_three" --prune --all >/dev/null
assert_missing "$tmp_root/backups-three/$home_three/.zshrc.old.240102000000"
assert_exists "$home_three/private.old.240102000000"

printf 'dots-backups-test: ok\n'
