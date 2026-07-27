#!/usr/bin/env bash

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

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
install_symlink "$HOME/dev/repos/NvChad" "$HOME/.config/nvim"


# Link in custom NvChad settings
if [ ! -h "$HOME/dev/repos/NvChad/lua/custom" ]; then
  ln -s "$HOME/dev/repos/nvim/lua/custom" "$HOME/dev/repos/NvChad/lua/custom"
fi
