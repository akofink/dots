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
  git clone https://github.com/akofink/dots.git $DOTS_REPO
fi

eval_template "$DOTS_REPO/templates/.gitignore" "$HOME/.gitignore"
eval_template "$DOTS_REPO/templates/.gitconfig" "$HOME/.gitconfig"

export REPOS_SETUP_COMPLETE=1
