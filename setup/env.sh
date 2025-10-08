#!/usr/bin/env bash

set -ae

if [ "$(basename -- "$0")" != "bootstrap.sh" ]; then
  if [[ -n "${ENV_SETUP_COMPLETE:-}" ]]; then
    return
  fi

  echo "🍄 Setting up common environment variables..."
fi

export DEV_REPOS="${DEV_REPOS:-"$HOME/dev/repos"}"
export DOTS_REPO="$DEV_REPOS/dots"

# Ensure USER
if [[ -z "${USER-}" ]]
then
  USER="$(id -un)"
  export USER
fi

# Set SUDO if non-root
if [[ "$USER" == "root" ]]
then
  SUDO=()
else
  SUDO=(sudo)
fi
export SUDO

PLATFORM="$(uname)"
export PLATFORM # Linux | Darwin
if [[ "$PLATFORM" == "Darwin" ]]
then
  PKG_MGR=(brew)
  PKG_INDEX_UPDATE_SUBCOMMAND=(update)
  PKG_INSTALL_SUBCOMMAND=(install -q)
  ENVSUBST_PKG=gettext
  # shellcheck disable=SC2034
  VIM_BUILD_DEPS=(gcc make libtool)
  # TMUX_BUILD_DEPS=(autoconf automake bison gcc libevent ncurses pkg-config utf8proc)
  # shellcheck disable=SC2034
  TMUX_BUILD_DEPS=() # rely on homebrew
  # shellcheck disable=SC2034
  RUBY_BUILD_DEPS=()
  PKG_LIST=(make)
  if [[ -n "$ENVSUBST_PKG" ]]; then
    PKG_LIST+=("$ENVSUBST_PKG")
  fi
  if [ ! -f /opt/homebrew/bin/brew ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ "$PLATFORM" == "Linux" ]]
then
  # shellcheck disable=SC2034
  ZSH_BUILD_DEPS=(zsh)

  # LINUX_COMMON_PKG_LIST=""
  if command -v yum &> /dev/null
  then
    PKG_MGR=("${SUDO[@]}" yum)
    PKG_INDEX_UPDATE_SUBCOMMAND=(check-update)
    PKG_INSTALL_SUBCOMMAND=(install -y)
    ENVSUBST_PKG=gettext-envsubst
    # shellcheck disable=SC2034
    VIM_BUILD_DEPS=(gcc make clang libtool ncurses-devel)
    # shellcheck disable=SC2034
    TMUX_BUILD_DEPS=(autoconf automake bison gcc g++ libevent-devel libncurses-devel locales pkg-config)
    # shellcheck disable=SC2034
    RUBY_BUILD_DEPS=()
    PKG_LIST=(make)
    if [[ -n "$ENVSUBST_PKG" ]]; then
      PKG_LIST+=("$ENVSUBST_PKG")
    fi
  elif command -v apt &> /dev/null
  then
    PKG_MGR=("${SUDO[@]}" apt)
    PKG_INDEX_UPDATE_SUBCOMMAND=(update)
    PKG_INSTALL_SUBCOMMAND=(install -y)
    ENVSUBST_PKG=gettext-base
    # shellcheck disable=SC2034
    VIM_BUILD_DEPS=(autoconf g++ gcc make ncurses-dev libx11-dev libxt-dev libxpm-dev libxmu-dev)
    # shellcheck disable=SC2034
    TMUX_BUILD_DEPS=(autoconf automake bison build-essential libevent-dev libncurses-dev locales pkg-config)
    # shellcheck disable=SC2034
    RUBY_BUILD_DEPS=(git autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev)
    PKG_LIST=(gettext)
    if [[ -n "$ENVSUBST_PKG" ]]; then
      PKG_LIST+=("$ENVSUBST_PKG")
    fi
  elif command -v apk &> /dev/null
  then
    PKG_MGR=("${SUDO[@]}" apk)
    PKG_INDEX_UPDATE_SUBCOMMAND=(update)
    PKG_INSTALL_SUBCOMMAND=(add)
    # shellcheck disable=SC2034
    VIM_BUILD_DEPS=(gcc make clang libtool-bin ncurses-dev)
    # shellcheck disable=SC2034
    TMUX_BUILD_DEPS=(autoconf automake bison build-essential libevent-dev libncurses-dev locales pkg-config)
    # shellcheck disable=SC2034
    RUBY_BUILD_DEPS=()
    ENVSUBST_PKG=gettext
    PKG_LIST=(shadow bash)
    if [[ -n "$ENVSUBST_PKG" ]]; then
      PKG_LIST+=("$ENVSUBST_PKG")
    fi
  else
    fatal "Failed to identify a package manager (yum, apt, apk, ?)"
  fi
fi


export PKG_MGR
export PKG_INSTALL=("${PKG_MGR[@]}" "${PKG_INSTALL_SUBCOMMAND[@]}")
export PKG_INDEX_UPDATE=("${PKG_MGR[@]}" "${PKG_INDEX_UPDATE_SUBCOMMAND[@]}")

set +e

printf 'Running: %s\n' "${PKG_INDEX_UPDATE[*]}"
"${PKG_INDEX_UPDATE[@]}"

set -e

if [[ ${#PKG_LIST[@]} -gt 0 ]]; then
  printf 'Installing: %s %s\n' "${PKG_INSTALL[*]}" "${PKG_LIST[*]}"
  "${PKG_INSTALL[@]}" "${PKG_LIST[@]}"
fi


export ENV_SETUP_COMPLETE=1
