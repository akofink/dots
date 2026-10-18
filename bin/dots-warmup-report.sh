#!/usr/bin/env bash
set -u

state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
pending="$state_home/dots-setup/pending"
failure="$state_home/dots-warmup/failure"
if [[ -s "$pending" ]]; then
  printf 'Dots setup pending interactive modules: %s\n' "$(<"$pending")"
  rm -f "$pending"
fi
if [[ -s "$failure" ]]; then
  printf 'Dots background warmup failed: %s\n' "$(<"$failure")" >&2
  rm -f "$failure"
fi
