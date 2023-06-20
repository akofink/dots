#!/usr/bin/env bash

mkdir -p ~/dev/repos/

# Clone NvChad
if [ ! -d ~/dev/repos/NvChad ]; then
  git clone https://github.com/NvChad/NvChad ~/dev/repos/NvChad --depth 1 && nvim
fi

# Clone personal nvim configs
if [ ! -d ~/dev/repos/nvim ]; then
  git clone https://github.com/akofink/nvim ~/dev/repos/nvim
fi

# Set up NvChad
if [ ! -h ~/.config/nvim ]; then
  if [ -d ~/.config/nvim ]; then
    mv ~/.config/{nvim,nvim.old.$(date +"%Y%m%dT%H%M%S")}
  fi
  ln -s ~/dev/repos/NvChad ~/.config/nvim
fi


# Link in custom NvChad settings
if [ ! -h ~/dev/repos/NvChad/lua/custom ]; then
  ln -s ~/dev/repos/nvim/lua/custom ~/dev/repos/NvChad/lua/custom
fi
