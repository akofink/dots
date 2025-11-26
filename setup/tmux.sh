#!/usr/bin/env bash

TMUX_VERSION=${TMUX_VERSION:-3.6}

if [[ -z "${REPOS_SETUP_COMPLETE:-}" ]]; then
  source setup/repos.sh
fi

if [[ ${#TMUX_BUILD_DEPS[@]} -gt 0 ]]; then
  "${PKG_INSTALL[@]}" "${TMUX_BUILD_DEPS[@]}"
fi

if [ ! -d "$HOME/dev/repos/tmux" ]; then
  mkdir -p "$HOME/dev/repos"
  git clone https://github.com/tmux/tmux.git "$HOME/dev/repos/tmux"
else
  cd "$HOME/dev/repos/tmux" || exit 1
  git fetch
fi

CONFIGURE_ARGS=()

# Function to check if we need to build/install tmux
should_build_tmux() {
  # If tmux command doesn't exist, we need to build it
  if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux command not found - will build"
    return 0
  fi

  # Check if current version matches desired version
  local current_version
  current_version=$(tmux -V 2>/dev/null | sed 's/tmux //')
  if [[ "$current_version" != "$TMUX_VERSION" ]]; then
    echo "tmux version mismatch (current: $current_version, desired: $TMUX_VERSION) - will build"
    return 0
  fi

  # Check if tmux binary is older than 24 hours
  local tmux_path
  tmux_path=$(command -v tmux)
  if [[ -n "$tmux_path" ]]; then
    # Check if file is older than 24 hours (1440 minutes)
    if [[ $(find "$tmux_path" -mmin +1440 2>/dev/null) ]]; then
      echo "tmux binary is older than 24 hours - will build"
      return 0
    fi
  fi

  echo "tmux is up to date"
  return 1
}

if should_build_tmux; then
  (
    cd "$HOME/dev/repos/tmux" || exit 1
    git checkout "$TMUX_VERSION"
    bash autogen.sh
    printf 'bash ./configure %s\n' "${CONFIGURE_ARGS[*]}"
    bash ./configure "${CONFIGURE_ARGS[@]}"
    make
    "${SUDO[@]}" make install
  )
fi

eval_template "$DOTS_REPO/templates/.tmux.conf" "$HOME/.tmux.conf"

# Set up TPM
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

(cd "$HOME/.tmux/plugins/tpm" && git pull)
