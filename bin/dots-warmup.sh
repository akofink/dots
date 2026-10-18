#!/usr/bin/env bash
set -u

repo=${DOTS_REPO:-"$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"}
state_root=${XDG_STATE_HOME:-"$HOME/.local/state"}/dots-warmup
now=${DOTS_WARMUP_NOW:-$(date +%s)}
if [[ ! "$now" =~ ^[0-9]+$ ]]; then
  printf 'Invalid warmup clock value\n' >&2
  exit 2
fi
updater=${DOTS_WARMUP_UPDATER:-"$repo/bin/akupdate.sh"}
mkdir -p "$state_root" || exit 1
status=0

run_gate() {
  local cadence=$1 interval=$2 stamp="$state_root/$1"
  if [[ -r "$stamp" ]]; then
    local previous
    previous=$(<"$stamp")
    [[ "$previous" =~ ^[0-9]+$ ]] || previous=0
    (( now - previous < interval )) && return 0
  fi
  if "$updater" "--warmup-$cadence"; then
    local tmp="$stamp.tmp.$$"
    if ! printf '%s\n' "$now" > "$tmp" || ! mv -f "$tmp" "$stamp"; then
      rm -f "$tmp"
      status=1
    fi
  else
    status=1
  fi
}

setup_command=${DOTS_WARMUP_SETUP:-"$repo/setup.sh"}
"$setup_command" --changed || status=1
run_gate daily 86400
if [[ "${MACHINE_CLASS:-personal}" != work ]]; then
  run_gate weekly 604800
fi
if (( status != 0 )); then
  printf 'Warmup failed; see %s\n' "${DOTS_WARMUP_LOG:-$state_root/warmup.log}" > "$state_root/failure"
fi
exit "$status"
