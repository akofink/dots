#!/usr/bin/env sh

PLATFORM="$(uname)" # Linux | Darwin
DEV_REPOS=${DEV_REPOS:-"$HOME/dev/repos"}
DOTS_REPO="$DEV_REPOS/dots"

err() { echo "$@" 1>&2; }
fatal() { err "$@" 1>&2; exit 1; }

if [[ -z "${USER-}" ]]
then
  USER="$(id -un)"
  export USER
fi

if [[ "$USER" == "root" ]]
then
  SUDO=""
else
  SUDO="sudo "
fi

if [[ "$PLATFORM" == "Darwin" ]]
then
  PKG_MGR="brew"
  PKG_INDEX_UPDATE="update"
  PKG_INSTALL="install"
elif [[ "$PLATFORM" == "Linux" ]]
then
  if command -v yum &> /dev/null
  then
    PKG_MGR="${SUDO}yum"
    PKG_INDEX_UPDATE="check-update"
    PKG_INSTALL="install -y"
  elif command -v apt &> /dev/null
  then
    PKG_MGR="${SUDO}apt"
    PKG_INDEX_UPDATE="update"
    PKG_INSTALL="install -y"
  elif command -v apk &> /dev/null
  then
    PKG_MGR="${SUDO}apk"
    PKG_INDEX_UPDATE="update"
    PKG_INSTALL="add"
  else
    fatal "Failed to identify a package manager (yum, apt, ?)"
  fi
fi

####################################################

$PKG_MGR $PKG_INDEX_UPDATE
$PKG_MGR $PKG_INSTALL git

mkdir -p "$DEV_REPOS"

if [[ ! -d "$DOTS_REPO" ]]
then
  git clone https://github.com/akofink/dots.git $DOTS_REPO
fi

source $DOTS_REPO/setup/*.sh
