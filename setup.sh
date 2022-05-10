#!/usr/bin/env bash

PLATFORM="$(uname)" # Linux | Darwin
DEV_REPOS=${DEV_REPOS:-"~/dev/repos"}
DOTS_REPO="$DEV_REPOS/dots"

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
elif [[ "$PLATFORM" == "Linux" ]]
then
  if command -v yum &> /dev/null
  then
    PKG_MGR="${SUDO}yum"
    ${SUDO}yum check-update # update package index
  elif command -v apt &> /dev/null
  then
    PKG_MGR="${SUDO}apt"
    ${SUDO}apt-get update # update package index
  fi
fi

err() { echo "$@" 1>&2; }

###################################################

$PKG_MGR install -y git

mkdir -p "$DEV_REPOS"

if [[ ! -d "$DOTS_REPO" ]]
then
  git clone https://github.com/akofink/dots.git $DOTS_REPO
fi

source "$DEV_REPOS/setup/*.sh"
