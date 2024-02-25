#!/usr/bin/env bash

source setup/env.sh
source setup/git.sh

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
