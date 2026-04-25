#!/usr/bin/env bash

echo
echo "🍄 Dots setup.sh started..."

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

for script in vim tmux zsh llm opencode rbenv tmuxinator glow; do
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
