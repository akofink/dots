#!/bin/bash

files=(
  ".zshrc"
  ".vimrc"
  ".tmux.conf"
  ".tmuxinator"
  ".gitconfig"
  ".gitignore"
)

if [ ! -d $(hostname -s) ]; then
  mkdir $(hostname -s)
fi

for file in "${files[@]}"; do
  if [ -f "$HOME/$file" ]; then
    cp -r "$HOME/$file" $(hostname -s)/
  fi
done
