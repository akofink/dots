#!/usr/bin/env bash

echo
echo "🍄 Dots setup.sh started..."

setup_modules=(http aws vim tmux zsh llm opencode rbenv go tmuxinator glow ghostty akagent)
selected_modules=("${setup_modules[@]}")
dry_run=0
changed_only=0
setup_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dots-setup"

print_usage() {
  cat <<'EOF'
Usage: ./setup.sh [--dry-run] [--changed] [--only module[,module...]]

Options:
  --dry-run              Print the selected modules without making changes.
  --changed              Select modules with missing or changed source fingerprints.
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
    --changed)
      changed_only=1
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

script_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DOTS_REPO=${DOTS_REPO:-$script_repo}
NOTES_REPO=${NOTES_REPO:-${DEV_REPOS:-"$HOME/dev/repos"}/notes}
export DOTS_REPO NOTES_REPO
sync_lock_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dots-sync/lock"
if [[ -d "$sync_lock_dir" && "${DOTS_WARMUP_LOCKED:-0}" != 1 ]]; then
  echo "Dots setup is already synchronized/warming; refusing to overlap lock: $sync_lock_dir" >&2
  exit 1
fi

module_fingerprint() {
  python3 "$DOTS_REPO/bin/dots-setup-state.py" "$1" "$DOTS_REPO" "$NOTES_REPO"
}

if [[ "$changed_only" -eq 1 ]]; then
  changed_modules=()
  for module in "${selected_modules[@]}"; do
    fingerprint=$(module_fingerprint "$module") || exit 1
    stamp="$setup_state_dir/$module"
    if [[ ! -r "$stamp" ]] || [[ "$(<"$stamp")" != "$fingerprint" ]]; then
      changed_modules+=("$module")
    fi
  done
  selected_modules=("${changed_modules[@]}")
fi

if [[ "$dry_run" -eq 1 ]]; then
  if [[ ${#selected_modules[@]} -eq 0 ]]; then
    printf 'No setup modules need to run.\n'
  else
    printf 'Would run setup modules: %s\n' "${selected_modules[*]}"
  fi
  exit 0
fi
if [[ "$changed_only" -eq 1 && ${#selected_modules[@]} -eq 0 ]]; then
  exit 0
fi

if [[ "$changed_only" -eq 0 && -z "${REPOS_SETUP_COMPLETE:-}" ]]; then
  # Full setup retains its repository and package bootstrap behavior.
  # Warmup mode must not source this side-effecting bootstrap path.
  # shellcheck source=setup/repos.sh
  source setup/repos.sh
fi

run_setup_script() {
  local name="$1"
  case "$name" in
    http)
      # shellcheck source=setup/http.sh
      source "$DOTS_REPO/setup/http.sh"
      ;;
    aws)
      # shellcheck source=setup/aws.sh
      source "$DOTS_REPO/setup/aws.sh"
      ;;
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
    ghostty)
      # shellcheck source=setup/ghostty.sh
      source "$DOTS_REPO/setup/ghostty.sh"
      ;;
    akagent)
      # shellcheck source=setup/akagent.sh
      source "$DOTS_REPO/setup/akagent.sh"
      ;;
    *)
      return 1
      ;;
  esac
}

deferred_modules=()
for script in "${selected_modules[@]}"; do
  # Only the isolated link/configuration pass is safe to apply unattended.
  # Other modules can install software, use the network, build, or require policy.
  if [[ "$changed_only" -eq 1 && "$script" != "llm" ]]; then
    deferred_modules+=("$script")
    continue
  fi
  script_path="$DOTS_REPO/setup/$script.sh"
  if [ -f "$script_path" ]; then
    echo
    echo "🍄 Running $script_path"
    if [[ "$changed_only" -eq 1 && "$script" == "llm" ]]; then
      DOTS_SETUP_ENV_ONLY=1 LLM_LINK_ONLY=1 run_setup_script "$script" || {
        echo "💩 Error running script $script_path" >&2
        exit 1
      }
    else
      run_setup_script "$script" || {
        echo "💩 Error running script $script_path" >&2
        exit 1
      }
    fi
    fingerprint=$(module_fingerprint "$script") || exit 1
    mkdir -p "$setup_state_dir" || { echo "Unable to create setup state: $setup_state_dir" >&2; exit 1; }
    stamp_tmp="$setup_state_dir/.${script}.$$"
    if ! printf '%s\n' "$fingerprint" > "$stamp_tmp" || ! mv -f "$stamp_tmp" "$setup_state_dir/$script"; then
      rm -f "$stamp_tmp"
      echo "Unable to record setup fingerprint for $script" >&2
      exit 1
    fi
  else
    echo "💩 Error - script does not exist: $script_path" >&2
    exit 1
  fi
done

if [[ "$changed_only" -eq 0 && "${selected_modules[*]}" == "${setup_modules[*]}" ]]; then
  rm -f "$setup_state_dir/pending"
fi

if [[ ${#deferred_modules[@]} -gt 0 ]]; then
  mkdir -p "$setup_state_dir" || { echo "Unable to create setup state: $setup_state_dir" >&2; exit 1; }
  pending_tmp="$setup_state_dir/pending.tmp.$$"
  if ! printf '%s\n' "${deferred_modules[*]}" > "$pending_tmp" || ! mv -f "$pending_tmp" "$setup_state_dir/pending"; then
    rm -f "$pending_tmp"
    echo "Unable to record pending setup modules" >&2
    exit 1
  fi
  [[ -t 1 ]] && printf 'Setup pending interactive modules: %s\n' "${deferred_modules[*]}"
fi

echo
echo "🎉🎉🎉🎉 Dots setup.sh success! 🎉🎉🎉🎉"
echo
