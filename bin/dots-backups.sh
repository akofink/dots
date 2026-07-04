#!/usr/bin/env bash

set -euo pipefail

mode=audit
root=${HOME:-}

usage() {
  cat <<'USAGE'
Usage: bin/dots-backups.sh [--root DIR] [--prune]

Audits dots-managed backup paths under DIR, defaulting to $HOME.

By default this is a dry run. It only reports backups that a prune run would
remove. Pass --prune to delete those redundant backups.

Only these dots backup suffixes are considered:
  .old.YYMMDDHHMMSS
  .old.YYYYMMDDTHHMMSS

The command always preserves the newest matching backup for each destination and
skips backups it cannot prove are redundant.
USAGE
}

err() { echo "$@" 1>&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      if [[ $# -lt 2 ]]; then
        err "Missing value for --root"
        exit 2
      fi
      root=$2
      shift 2
      ;;
    --prune)
      mode=prune
      shift
      ;;
    --dry-run|--audit)
      mode=audit
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      err "Unknown argument: $1"
      usage 1>&2
      exit 2
      ;;
  esac
done

if [[ -z "$root" || ! -d "$root" ]]; then
  err "Backup root is not a directory: $root"
  exit 2
fi

root=$(cd -- "$root" && pwd -P)

timestamp_for_backup() {
  local path=$1
  local suffix=${path##*.old.}

  case "$suffix" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9])
      printf '20%s\n' "$suffix"
      ;;
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9])
      printf '%s%s\n' "${suffix%T*}" "${suffix#*T}"
      ;;
    *)
      return 1
      ;;
  esac
}

destination_for_backup() {
  local path=$1
  local suffix=${path##*.old.}
  printf '%s\n' "${path%".old.$suffix"}"
}

same_contents() {
  local left=$1
  local right=$2

  if [[ -L "$left" && -L "$right" ]]; then
    [[ $(readlink "$left") == "$(readlink "$right")" ]]
    return
  fi

  if [[ -f "$left" && -f "$right" ]]; then
    cmp -s -- "$left" "$right"
    return
  fi

  if [[ -d "$left" && -d "$right" ]]; then
    diff -qr -- "$left" "$right" >/dev/null
    return
  fi

  return 1
}

list_backups() {
  find "$root" -name '*.old.*' -print0 -prune
}

has_newer_backup() {
  local backup=$1
  local destination=$2
  local timestamp=$3
  local other
  local other_destination
  local other_timestamp

  while IFS= read -r -d '' other; do
    other_destination=$(destination_for_backup "$other") || continue
    [[ "$other_destination" == "$destination" ]] || continue

    other_timestamp=$(timestamp_for_backup "$other") || continue
    if [[ "$other_timestamp" > "$timestamp" && "$other" != "$backup" ]]; then
      return 0
    fi
  done < <(list_backups)

  return 1
}

matches_newer_backup() {
  local backup=$1
  local destination=$2
  local timestamp=$3
  local other
  local other_destination
  local other_timestamp

  while IFS= read -r -d '' other; do
    other_destination=$(destination_for_backup "$other") || continue
    [[ "$other_destination" == "$destination" ]] || continue

    other_timestamp=$(timestamp_for_backup "$other") || continue
    if [[ "$other_timestamp" > "$timestamp" && "$other" != "$backup" ]]; then
      if same_contents "$backup" "$other"; then
        return 0
      fi
    fi
  done < <(list_backups)

  return 1
}

scanned=0
skipped=0
redundant=0
deleted=0

echo "Mode: $mode"
echo "Root: $root"

while IFS= read -r -d '' backup; do
  if ! timestamp=$(timestamp_for_backup "$backup"); then
    continue
  fi

  scanned=$((scanned + 1))
  destination=$(destination_for_backup "$backup")

  if ! has_newer_backup "$backup" "$destination" "$timestamp"; then
    echo "KEEP newest: $backup"
    continue
  fi

  reason=
  if [[ -e "$destination" || -L "$destination" ]] && same_contents "$backup" "$destination"; then
    reason="matches current destination"
  elif matches_newer_backup "$backup" "$destination" "$timestamp"; then
    reason="matches a newer backup"
  fi

  if [[ -z "$reason" ]]; then
    skipped=$((skipped + 1))
    echo "SKIP unique-or-uncertain: $backup"
    continue
  fi

  redundant=$((redundant + 1))
  if [[ "$mode" == prune ]]; then
    rm -rf -- "$backup"
    deleted=$((deleted + 1))
    echo "DELETE $backup ($reason)"
  else
    echo "WOULD DELETE $backup ($reason)"
  fi
done < <(list_backups)

echo "Summary: scanned=$scanned redundant=$redundant skipped=$skipped deleted=$deleted"

if [[ "$mode" != prune ]]; then
  echo "Dry run only. Re-run with --prune to delete the WOULD DELETE paths."
fi
