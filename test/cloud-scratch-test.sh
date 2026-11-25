#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/root/dots/bin"
cp "$repo_root/bin/notes-task.py" "$tmp/root/dots/bin/"

# Read-only HOME: scratch mode builds env.sh and a notes-task wrapper without touching HOME.
CLOUD_SCRATCH="$tmp/scratch" HOME=/proc bash "$repo_root/bin/cloud-scratch-setup.sh" "$tmp/root" >/dev/null
[[ -f "$tmp/scratch/env.sh" ]]
grep -q "NOTES_REPO='$tmp/root/notes'" "$tmp/scratch/env.sh"
grep -q 'GIT_CONFIG_KEY_0=commit.gpgsign' "$tmp/scratch/env.sh"
[[ -x "$tmp/scratch/bin/notes-task" ]]
"$tmp/scratch/bin/notes-task" --help | grep -q 'usage: notes-task'

# Signing is off through the environment, not a config file.
(source "$tmp/scratch/env.sh"; [[ "$(git config commit.gpgsign)" == false ]])

printf 'cloud-scratch-test: ok\n'
