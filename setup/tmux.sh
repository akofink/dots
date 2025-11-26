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
if ! command -v tmux >/dev/null 2>&1; then
  if [[ "$PLATFORM" == "Darwin" ]]; then
    "${PKG_INSTALL[@]}" tmux
  else
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
fi

eval_template "$DOTS_REPO/templates/.tmux.conf" "$HOME/.tmux.conf"

# Set up TPM
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

(cd "$HOME/.tmux/plugins/tpm" && git pull)
