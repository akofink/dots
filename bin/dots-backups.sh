#!/usr/bin/env bash

set -euo pipefail

mode=audit
root=${HOME:-}
delete_newest=0
delete_all=0
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DOTS_REPO=${DOTS_REPO:-$(cd -- "$script_dir/.." && pwd)}

usage() {
  cat <<'USAGE'
Usage: bin/dots-backups.sh [--root DIR] [--prune] [--delete-newest | --all]

Audits dots-managed backup paths under DIR, defaulting to $HOME.

By default this is a dry run. It only reports backups that a prune run would
remove. Pass --prune to delete those redundant backups.

The scan is restricted to destinations this dots repo is known to manage,
including top-level dotfiles, known template destinations, and configured agent
skill/config paths. It does not walk all of DIR.

Only these dots backup suffixes are considered:
  .old.YYMMDDHHMMSS
  .old.YYYYMMDDTHHMMSS

The command always preserves the newest matching backup for each destination and
skips backups it cannot prove are redundant.

Cleanup options:
  --delete-newest  Also select the newest backup for a known destination, but
                   only when it matches the current destination.
  --all            Select every matching backup for known destinations. This is
                   intentionally explicit because it can delete unique backups.
                   Pass with --prune to delete the selected backups.
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
    --delete-newest)
      delete_newest=1
      shift
      ;;
    --all)
      delete_all=1
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

if [[ $delete_newest -eq 1 && $delete_all -eq 1 ]]; then
  err "Choose only one of --delete-newest or --all"
  exit 2
fi

if [[ -z "$root" || ! -d "$root" ]]; then
  err "Backup root is not a directory: $root"
  exit 2
fi

root=$(cd -- "$root" && pwd -P)

add_destination() {
  local destination=$1
  destinations+=("$destination")
}

add_skill_destinations() {
  local destination_root=$1
  shift
  local skill_name

  for skill_name in "$@"; do
    add_destination "$destination_root/$skill_name"
  done
}

path_is_under_root() {
  local path=$1

  [[ "$path" == "$root" || "$path" == "$root"/* ]]
}

known_destinations() {
  local home_root=$root
  local config_root
  local glow_config_dir
  local vim_template
  local common_skills=(agent-orchestrator coding-workflow no-mistakes pr-review skills-via-dots-notes tmux)
  local work_skills=(atlas-updates jira-ticket-authoring working-state-cleanup)

  config_root=${XDG_CONFIG_HOME:-$home_root/.config}
  if [[ "$config_root" != /* ]]; then
    config_root="$home_root/$config_root"
  fi

  case "$(uname -s)" in
    Darwin)
      glow_config_dir="$home_root/Library/Preferences/glow"
      ;;
    *)
      glow_config_dir="$config_root/glow"
      ;;
  esac

  local -a destinations=()

  add_destination "$home_root/.gitconfig"
  add_destination "$home_root/.gitignore"
  add_destination "$home_root/.tmux.conf"
  add_destination "$home_root/.vimrc"
  add_destination "$home_root/.zshenv"
  add_destination "$home_root/.zshrc"
  add_destination "$home_root/.oh-my-zsh/custom/themes/akofink.zsh-theme"

  for vim_template in "$DOTS_REPO"/templates/dot_vim/*; do
    [[ -e "$vim_template" ]] || continue
    add_destination "$home_root/.vim/$(basename -- "$vim_template")"
  done

  add_destination "$glow_config_dir/glow.yml"
  add_destination "$glow_config_dir/solarized-light.json"
  add_destination "$glow_config_dir/solarized-dark.json"

  add_destination "$home_root/.codex/config.toml"
  add_destination "$home_root/.codex/instructions.md"
  add_destination "$home_root/.codex/rules/dots.rules"
  add_destination "$home_root/.config/opencode/opencode.jsonc"
  add_destination "$home_root/.rovodev/config.yml"

  add_destination "$home_root/.agents/AGENTS.md"
  add_destination "$home_root/.claude/AGENTS.md"
  add_destination "$home_root/.claude/CLAUDE.md"
  add_destination "$home_root/.claude/agents/test-writer.md"
  add_destination "$home_root/.codex/AGENTS.md"
  add_destination "$home_root/.config/opencode/AGENTS.md"
  add_destination "$home_root/.pi/AGENTS.md"
  add_destination "$home_root/.rovodev/AGENTS.md"
  add_destination "$home_root/.rovo/AGENTS.md"
  add_destination "$home_root/dev/AGENTS.md"
  add_destination "$home_root/dev/AGENTS.bbc-core.md"
  add_destination "$home_root/dev/AGENTS.dss.md"

  add_skill_destinations "$home_root/.agents/skills" "${common_skills[@]}" "${work_skills[@]}"
  add_skill_destinations "$home_root/.claude/skills" "${common_skills[@]}" "${work_skills[@]}"
  add_skill_destinations "$home_root/.codex/skills" "${common_skills[@]}" "${work_skills[@]}"
  add_skill_destinations "$home_root/.config/opencode/skills" "${common_skills[@]}" "${work_skills[@]}"
  add_skill_destinations "$home_root/.pi/skills" "${common_skills[@]}" "${work_skills[@]}"
  add_skill_destinations "$home_root/.rovodev/skills" "${common_skills[@]}" "${work_skills[@]}"
  add_skill_destinations "$home_root/dev/.rovodev/skills" "${common_skills[@]}" "${work_skills[@]}"

  add_destination "$home_root/.config/tmuxinator"
  add_destination "$home_root/.config/nvim"

  printf '%s\0' "${destinations[@]}"
}

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
  local destination
  local backup

  while IFS= read -r -d '' destination; do
    path_is_under_root "$destination" || continue
    for backup in "$destination".old.*; do
      [[ -e "$backup" || -L "$backup" ]] || continue
      printf '%s\0' "$backup"
    done
  done < <(known_destinations)
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
echo "Scope: known dots-managed destinations only"
if [[ $delete_all -eq 1 ]]; then
  echo "Prune policy: delete all matching backups for known destinations"
elif [[ $delete_newest -eq 1 ]]; then
  echo "Prune policy: delete redundant backups, including newest backups that match current destinations"
else
  echo "Prune policy: preserve newest backup for each destination"
fi

while IFS= read -r -d '' backup; do
  if ! timestamp=$(timestamp_for_backup "$backup"); then
    continue
  fi

  scanned=$((scanned + 1))
  destination=$(destination_for_backup "$backup")

  reason=
  if [[ $delete_all -eq 1 ]]; then
    reason="--all requested"
  elif has_newer_backup "$backup" "$destination" "$timestamp"; then
    if [[ -e "$destination" || -L "$destination" ]] && same_contents "$backup" "$destination"; then
      reason="matches current destination"
    elif matches_newer_backup "$backup" "$destination" "$timestamp"; then
      reason="matches a newer backup"
    fi
  elif [[ $delete_newest -eq 1 ]]; then
    if [[ -e "$destination" || -L "$destination" ]] && same_contents "$backup" "$destination"; then
      reason="newest backup matches current destination"
    else
      echo "KEEP newest: $backup"
      continue
    fi
  else
    echo "KEEP newest: $backup"
    continue
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
