#!/usr/bin/env bash
set -u

state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
pending="$state_home/dots-setup/pending"
failure="$state_home/dots-warmup/failure"
action_list_helper=${DOTS_ACTION_LIST_HELPER:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/personal-action-list.py"}
if [[ -f "$action_list_helper" ]]; then
  python3 "$action_list_helper"
fi
if [[ -s "$pending" ]]; then
  printf 'Dots setup pending interactive modules: %s\n' "$(<"$pending")"
  rm -f "$pending"
fi
if [[ -s "$failure" ]]; then
  printf 'Dots background warmup failed: %s\n' "$(<"$failure")" >&2
  rm -f "$failure"
fi
