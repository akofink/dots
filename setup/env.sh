#!/usr/bin/env bash

if [ $ENV_SETUP_COMPLETE ]; then
  return
fi

echo "Setting up common environment variables..."

export DEV_REPOS=${DEV_REPOS:-"$HOME/dev/repos"}
export DOTS_REPO="$DEV_REPOS/dots"

source "$DOTS_REPO/util.sh"

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
  PKG_INSTALL_SUBCOMMAND="install -q"
  if [ ! -f /opt/homebrew/bin/brew ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ "$PLATFORM" == "Linux" ]]
then
  LINUX_COMMON_PKG_LIST=""
  if command -v yum &> /dev/null
  then
    PKG_MGR=($SUDO yum)
    PKG_INDEX_UPDATE_SUBCOMMAND=(check-update)
    PKG_INSTALL_SUBCOMMAND=(install -y)
    PKG_LIST="gettext make"
  elif command -v apt &> /dev/null
  then
    PKG_MGR=($SUDO apt)
    PKG_INDEX_UPDATE_SUBCOMMAND=(update)
    PKG_INSTALL_SUBCOMMAND=(install -y)
    PKG_LIST=(gettext build-essential)
  elif command -v apk &> /dev/null
  then
    PKG_MGR=($SUDO apk)
    PKG_INDEX_UPDATE_SUBCOMMAND=(update)
    PKG_INSTALL_SUBCOMMAND=(add)
    PKG_LIST=(gettext shadow)
  else
    fatal "Failed to identify a package manager (yum, apt, apk, ?)"
  fi
fi

export PKG_MGR
export PKG_INSTALL=($PKG_MGR $PKG_INSTALL_SUBCOMMAND)
export PKG_INDEX_UPDATE=($PKG_MGR $PKG_INDEX_UPDATE_SUBCOMMAND)

export ENV_SETUP_COMPLETE=1

