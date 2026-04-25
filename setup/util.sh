#!/usr/bin/env bash

# shellcheck source-path=SCRIPTDIR

if ! declare -F err >/dev/null 2>&1; then
  err() { echo "$@" 1>&2; }
fi

if ! declare -F fatal >/dev/null 2>&1; then
  fatal() { err "$@" 1>&2; exit 1; }
fi

if [[ -z "${DOTS_REPO:-}" ]]; then
  util_script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  DOTS_REPO=$(cd -- "$util_script_dir/.." && pwd)
  export DOTS_REPO
fi

if [[ -n "${UTIL_SETUP_COMPLETE:-}" ]]; then
  return
fi

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

if [[ -z "${ENV_SETUP_COMPLETE:-}" ]]; then
  script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  if [[ -z "$script_dir" ]]; then
    fatal "Unable to determine util.sh directory"
  fi

  if ! pushd "$script_dir" > /dev/null; then
    fatal "Failed to enter $script_dir"
  fi

  # shellcheck source=setup/env.sh
  source env.sh

  if ! popd > /dev/null; then
    fatal "Failed to return from $script_dir"
  fi
fi

# Returns 0 when an archived copy of the destination already has the same contents.
destination_has_matching_backup() {
  local destination="$1"
  local backup
  for backup in "$destination".old.*; do
    [[ -e "$backup" ]] || continue
    if cmp -s "$destination" "$backup"; then
      return 0
    fi
  done
  return 1
}

# Creates a timestamped backup when no existing archive matches current contents.
backup_destination_if_needed() {
  local destination="$1"

  if destination_has_matching_backup "$destination"; then
    return
  fi

  local timestamp
  timestamp=$(date +%y%m%d%H%M%S) || fatal "Failed to generate backup timestamp"
  mv "$destination" "$destination.old.$timestamp"
}

# eval_template templates/.vimrc.template ~/.vimrc
# eval_template templates/.zshrc ~/.zshrc '$GIT_EMAIL $GIT_SIGNINGKEY'
#
# Safely applies envsubst to a template file and installs it at the destination.
# Archives existing destination files in place by appending a timestamp.
#
# 1: template file
# 2: destination file
# 3: (optional) shell-format string of variables to substitute, e.g. '$FOO $BAR'.
#    When provided, only the listed variables are expanded; all other $VAR
#    references are passed through verbatim, which is essential for templates
#    (such as .zshrc) that contain runtime shell variables alongside the
#    setup-time variables being substituted.
#    When omitted, envsubst expands every $VAR in the template.
eval_template() {
  local template="$1"
  local destination="$2"
  local subst_vars="${3:-}"

  if [[ -z "$destination" ]]; then
    return
  fi

  if ! command -v envsubst &> /dev/null; then
    fatal "No envsubst command found!"
  fi

  local rendered
  rendered=$(mktemp) || fatal "Failed to create temp file for rendering $template"
  # Render the template once so we can compare before overwriting.
  # Pass $subst_vars as a positional argument only when set; an empty string
  # would tell envsubst to substitute nothing at all.
  if [[ -n "$subst_vars" ]]; then
    if ! envsubst "$subst_vars" < "$template" > "$rendered"; then
      rm -f "$rendered"
      fatal "Failed to render template $template"
    fi
  else
    if ! envsubst < "$template" > "$rendered"; then
      rm -f "$rendered"
      fatal "Failed to render template $template"
    fi
  fi

  if [[ -f "$destination" ]]; then
    # Nothing to do when the destination already matches the rendered template.
    if cmp -s "$rendered" "$destination"; then
      rm -f "$rendered"
      return
    fi

    # Only archive the current file when its contents are not already preserved.
    backup_destination_if_needed "$destination"
  fi

  if ! cat "$rendered" > "$destination"; then
    rm -f "$rendered"
    fatal "Failed to write rendered template to $destination"
  fi
  rm -f "$rendered"
}

export UTIL_SETUP_COMPLETE=1
