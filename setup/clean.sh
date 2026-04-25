#!/usr/bin/env bash

clean_commands() {
  cat <<'EOF'
unset ENV_SETUP_COMPLETE
unset UTIL_SETUP_COMPLETE
unset GIT_SETUP_COMPLETE
unset REPOS_SETUP_COMPLETE
unset VIM_SETUP_COMPLETE
unset TMUX_SETUP_COMPLETE
unset ZSH_SETUP_COMPLETE
unset RBENV_SETUP_COMPLETE
unset TMUXINATOR_SETUP_COMPLETE
unset LLM_SETUP_COMPLETE
unset OPENCODE_SETUP_COMPLETE
unset GO_SETUP_COMPLETE
unset GLOW_SETUP_COMPLETE
unset DEV_REPOS
unset DOTS_REPO
unset PLATFORM
unset SUDO
unset PKG_MGR
unset PKG_INSTALL
unset PKG_INDEX_UPDATE
unset HAS_JAMF
unset IS_WORK_MACHINE
unset GIT_EMAIL
unset GIT_SIGNINGKEY
unset GITHUB_USER
unset GIT_CREDENTIAL_HELPER
unset ENVSUBST_PKG
unset PKG_LIST
unset VIM_BUILD_DEPS
unset TMUX_BUILD_DEPS
unset RUBY_BUILD_DEPS
unset ZSH_BUILD_DEPS
EOF
}

if [[ "${1:-}" == "--print" ]]; then
  clean_commands
  exit 0
fi

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo 'eval "$(make clean)"'
  echo "This helper must be sourced, or run via make clean with eval, to affect the current shell."
  exit 1
fi

eval "$(clean_commands)"
echo "Cleared exported dots setup state from the current shell."
