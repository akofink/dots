#!/usr/bin/env bash


if [ $REPOS_SETUP_COMPLETE ]; then
  return
fi

if [ ! $GIT_SETUP_COMPLETE ]; then
  source setup/git.sh
fi

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


export REPOS_SETUP_COMPLETE=1
