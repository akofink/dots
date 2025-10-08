#!/usr/bin/env bash

mkdir -p ~/dev/repos/

# Clone NvChad
if [ ! -d "$HOME/dev/repos/NvChad" ]; then
  git clone https://github.com/NvChad/NvChad "$HOME/dev/repos/NvChad" --depth 1
fi

# Clone personal nvim configs
if [ ! -d "$HOME/dev/repos/nvim" ]; then
  git clone https://github.com/akofink/nvim "$HOME/dev/repos/nvim"
fi

# Set up NvChad
mkdir -p "$HOME/.config"
if [ ! -h "$HOME/.config/nvim" ]; then
  if [ -d "$HOME/.config/nvim" ]; then
    timestamp="$(date +"%Y%m%dT%H%M%S")"
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.old.$timestamp"
  fi
  ln -s "$HOME/dev/repos/NvChad" "$HOME/.config/nvim"
fi


# Link in custom NvChad settings
if [ ! -h "$HOME/dev/repos/NvChad/lua/custom" ]; then
  ln -s "$HOME/dev/repos/nvim/lua/custom" "$HOME/dev/repos/NvChad/lua/custom"
fi
