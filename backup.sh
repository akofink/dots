#!/bin/bash

files=(
  ".zshrc"
  ".vimrc"
  ".tmux.conf"
  ".tmuxinator"
  ".gitconfig"
  ".gitignore"
)

if [ ! -d backups/$(hostname -s) ]; then
  mkdir -p backups/$(hostname -s)
fi

for file in "${files[@]}"; do
  if [ -f "$HOME/$file" ]; then
    cp -r "$HOME/$file" backups/$(hostname -s)/
  fi
done
