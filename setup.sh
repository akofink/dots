#!/usr/bin/env bash

echo
echo "🍄 Dots setup.sh started..."

setup_modules=(vim tmux zsh llm opencode rbenv go tmuxinator glow)
selected_modules=("${setup_modules[@]}")
dry_run=0

print_usage() {
  cat <<'EOF'
Usage: ./setup.sh [--dry-run] [--only module[,module...]]

Options:
  --dry-run              Print the selected modules without making changes.
  --only module[,module] Run only the named curated modules.
  --help                 Show this help message.
EOF
}

is_setup_module() {
  local candidate="$1"
  local module
  for module in "${setup_modules[@]}"; do
    [[ "$module" == "$candidate" ]] && return 0
  done
  return 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=1
      ;;
    --only)
      if [[ $# -lt 2 ]]; then
        echo "Error: --only requires a comma-separated module list." >&2
        exit 1
      fi
      IFS=',' read -r -a selected_modules <<< "$2"
      shift
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      echo "Error: unknown option: $1" >&2
      print_usage >&2
      exit 1
      ;;
  esac
  shift
done

for module in "${selected_modules[@]}"; do
  if [[ -z "$module" ]] || ! is_setup_module "$module"; then
    echo "Error: unknown setup module: $module" >&2
    print_usage >&2
    exit 1
  fi
done

if [[ "$dry_run" -eq 1 ]]; then
  printf 'Would run setup modules: %s\n' "${selected_modules[*]}"
  exit 0
fi

if [[ -z "${REPOS_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/repos.sh
  source setup/repos.sh
fi

run_setup_script() {
  local name="$1"
  case "$name" in
    vim)
      # shellcheck source=setup/vim.sh
      source "$DOTS_REPO/setup/vim.sh"
      ;;
    tmux)
      # shellcheck source=setup/tmux.sh
      source "$DOTS_REPO/setup/tmux.sh"
      ;;
    zsh)
      # shellcheck source=setup/zsh.sh
      source "$DOTS_REPO/setup/zsh.sh"
      ;;
    llm)
      # shellcheck source=setup/llm.sh
      source "$DOTS_REPO/setup/llm.sh"
      ;;
    opencode)
      # shellcheck source=setup/opencode.sh
      source "$DOTS_REPO/setup/opencode.sh"
      ;;
    rbenv)
      # shellcheck source=setup/rbenv.sh
      source "$DOTS_REPO/setup/rbenv.sh"
      ;;
    go)
      # shellcheck source=setup/go.sh
      source "$DOTS_REPO/setup/go.sh"
      ;;
    tmuxinator)
      # shellcheck source=setup/tmuxinator.sh
      source "$DOTS_REPO/setup/tmuxinator.sh"
      ;;
    glow)
      # shellcheck source=setup/glow.sh
      source "$DOTS_REPO/setup/glow.sh"
      ;;
    *)
      return 1
      ;;
  esac
}

for script in "${selected_modules[@]}"; do
  script_path="$DOTS_REPO/setup/$script.sh"
  if [ -f "$script_path" ]; then
    echo
    echo "🍄 Running $script_path"
    run_setup_script "$script" || {
      echo "💩 Error running script $script_path"
      exit 1
    }
  else
    echo "💩 Error - script does not exist: $script_path"
  fi
done

echo
echo "🎉🎉🎉🎉 Dots setup.sh success! 🎉🎉🎉🎉"
echo
