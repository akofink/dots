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

update_apt() {
  [[ "${MACHINE_CLASS:-personal}" != work ]] || return 0
  command -v apt-get >/dev/null 2>&1 || return 0
  sudo -n apt-get update && sudo -n apt-get -y upgrade
}

update_npm_globals() {
  command -v npm >/dev/null 2>&1 || return 0
  npm update -g --no-fund --no-audit
}

update_llm_clis() {
  local result=0
  pi update --all || result=1
  claude update || result=1
  codex update || result=1
  return "$result"
}

print_summary() {
  printf '\nUpdate summary:\n'
  printf '  %s\n' "${results[@]}"
}

main() {
  case "${1:-}" in
    --warmup-daily)
      run_step "LLM CLIs" update_llm_clis
      print_summary
      return "$failed"
      ;;
    --warmup-weekly)
      if [[ "${MACHINE_CLASS:-personal}" == work ]]; then
        results+=("Package updates: deferred by work machine policy")
      else
        run_step "Homebrew packages" update_brew
        run_step "APT packages" update_apt
        run_step "npm globals" update_npm_globals
      fi
      print_summary
      return "$failed"
      ;;
    --help)
      printf 'Usage: %s [--warmup-daily|--warmup-weekly]\n' "$0"
      return 0
      ;;
  esac
  run_step "Homebrew packages" update_brew
  run_step "Pi and extensions" pi update --all
  run_step "Claude Code" claude update
  run_step "Codex" codex update

  if [[ "${MACHINE_CLASS:-personal}" == "work" ]]; then
    run_step "Atlas CLI" atlas update
    run_step "Atlas plugins" atlas plugin update --all
  fi

  print_summary
  return "$failed"
}

main "$@"
