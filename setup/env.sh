#!/usr/bin/env bash

set -ae

if [ "$(basename -- "$0")" != "bootstrap.sh" ]; then
  if [ $ENV_SETUP_COMPLETE ]; then
    return
  fi

  echo "🍄 Setting up common environment variables..."
fi

export DEV_REPOS=${DEV_REPOS:-"$HOME/dev/repos"}
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

export PLATFORM="$(uname)" # Linux | Darwin
if [[ "$PLATFORM" == "Darwin" ]]
then
  PKG_MGR=(brew)
  PKG_INDEX_UPDATE_SUBCOMMAND="update"
  PKG_INSTALL_SUBCOMMAND=(install -q)
  ENVSUBST_PKG=gettext
  VIM_BUILD_DEPS=(gcc make libtool)
  # TMUX_BUILD_DEPS=(autoconf automake bison gcc libevent ncurses pkg-config utf8proc)
  TMUX_BUILD_DEPS=() # rely on homebrew
  PKG_LIST=(make $ENVSUBST_PKG)
  if [ ! -f /opt/homebrew/bin/brew ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ "$PLATFORM" == "Linux" ]]
then
  ZSH_BUILD_DEPS=(zsh)

  # LINUX_COMMON_PKG_LIST=""
  if command -v yum &> /dev/null
  then
    PKG_MGR=($SUDO yum)
    PKG_INDEX_UPDATE_SUBCOMMAND=(check-update)
    PKG_INSTALL_SUBCOMMAND=(install -y)
    ENVSUBST_PKG=gettext-envsubst
    VIM_BUILD_DEPS=(gcc make clang libtool ncurses-devel)
    TMUX_BUILD_DEPS=(autoconf automake bison gcc g++ libevent-devel libncurses-devel locales pkg-config)
    PKG_LIST=(make $ENVSUBST_PKG)
  elif command -v apt &> /dev/null
  then
    PKG_MGR=($SUDO apt)
    PKG_INDEX_UPDATE_SUBCOMMAND=(update)
    PKG_INSTALL_SUBCOMMAND=(install -y)
    ENVSUBST_PKG=gettext-base
    VIM_BUILD_DEPS=(autoconf g++ gcc make ncurses-dev libx11-dev libxt-dev libxpm-dev libxmu-dev)
    TMUX_BUILD_DEPS=(autoconf automake bison build-essential libevent-dev libncurses-dev locales pkg-config)
    PKG_LIST=(gettext $ENVSUBST_PKG)
  elif command -v apk &> /dev/null
  then
    PKG_MGR=($SUDO apk)
    PKG_INDEX_UPDATE_SUBCOMMAND=(update)
    PKG_INSTALL_SUBCOMMAND=(add)
    VIM_BUILD_DEPS=(gcc make clang libtool-bin ncurses-dev)
    TMUX_BUILD_DEPS=(autoconf automake bison build-essential libevent-dev libncurses-dev locales pkg-config)
    ENVSUBST_PKG=gettext
    PKG_LIST=(shadow $ENVSUBST_PKG)
  else
    fatal "Failed to identify a package manager (yum, apt, apk, ?)"
  fi
fi


export PKG_MGR
export PKG_INSTALL=(${PKG_MGR[@]} ${PKG_INSTALL_SUBCOMMAND[@]})
export PKG_INDEX_UPDATE=(${PKG_MGR[@]} ${PKG_INDEX_UPDATE_SUBCOMMAND[@]})

set +e

echo ${PKG_INDEX_UPDATE[@]}
${PKG_INDEX_UPDATE[@]}

set -e

echo ${PKG_INSTALL[@]} ${PKG_LIST[@]}
${PKG_INSTALL[@]} ${PKG_LIST[@]}


export ENV_SETUP_COMPLETE=1
