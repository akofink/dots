#!/bin/bash

files=( "$HOME/.zshrc" "$HOME/.vimrc" "$HOME/.tmux.conf" "$HOME/.tmuxinator" "$HOME/.gitconfig" )

for file in "${files[@]}"; do
  cp -r $file $(hostname -s)/
done
