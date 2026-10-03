#!/usr/bin/env bash

set -u

results=()
failed=0

run_step() {
  local name="$1"
  shift

  printf '→ %s\n' "$name"
  if "$@"; then
    results+=("$name: OK")
  else
    local status=$?
    results+=("$name: FAILED (exit $status)")
    failed=1
  fi
}

update_brew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is not installed or not on PATH" >&2
    return 1
  fi
  brew update && brew upgrade
}

main() {
  run_step "Homebrew packages" update_brew
  run_step "Pi and extensions" pi update --all
  run_step "Claude Code" claude update
  run_step "Codex" codex update

  if [[ "${MACHINE_CLASS:-personal}" == "work" ]]; then
    run_step "Atlas CLI" atlas update
    run_step "Atlas plugins" atlas plugin update --all
  fi

  printf '\nUpdate summary:\n'
  printf '  %s\n' "${results[@]}"
  return "$failed"
}

main "$@"
