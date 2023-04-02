#!/usr/bin/env bash

export PLATFORM="$(uname)" # Linux | Darwin
export DEV_REPOS=${DEV_REPOS:-"$HOME/dev/repos"}
export DOTS_REPO="$DEV_REPOS/dots"

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
export SUDO

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
    PKG_LIST="gettext-envsubst"
  elif command -v apt &> /dev/null
  then
    PKG_MGR="${SUDO}apt"
    PKG_INDEX_UPDATE="update"
    PKG_INSTALL="install -y"
    PKG_LIST="gettext"
  elif command -v apk &> /dev/null
  then
    PKG_MGR="${SUDO}apk"
    PKG_INDEX_UPDATE="update"
    PKG_INSTALL="add"
    PKG_LIST="gettext"
  else
    fatal "Failed to identify a package manager (yum, apt, apk, ?)"
  fi
fi

####################################################

$PKG_MGR $PKG_INDEX_UPDATE
$PKG_MGR $PKG_INSTALL git $PKG_LIST

mkdir -p "$DEV_REPOS"

if [[ ! -d "$DOTS_REPO" ]]
then
  if [[ -d "/app" ]] # For local testing in docker (see Dockerfile)
  then
    ln -s /app $DOTS_REPO
  else
    git clone https://github.com/akofink/dots.git $DOTS_REPO
  fi
fi

source $DOTS_REPO/setup/*.sh
