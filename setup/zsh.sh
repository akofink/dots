#!/usr/bin/env bash

if [[ -z "${REPOS_SETUP_COMPLETE:-}" ]]; then
  source setup/repos.sh
fi

if [[ ${#ZSH_BUILD_DEPS[@]} -gt 0 ]]; then
  "${PKG_INSTALL[@]}" "${ZSH_BUILD_DEPS[@]}"
fi

# oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh/lib" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# oh-my-zsh plugins
ZSH_CUSTOM_PLUGIN_ROOT=${ZSH_CUSTOM:-"$HOME/.oh-my-zsh/custom"}
ZSH_CUSTOM_PLUGIN_DIR="$ZSH_CUSTOM_PLUGIN_ROOT/plugins"
if [ ! -d "$ZSH_CUSTOM_PLUGIN_DIR/zsh-autosuggestions" ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_PLUGIN_DIR/zsh-autosuggestions"
fi

mkdir -p "$HOME/.oh-my-zsh/custom/themes/"
cp "$DOTS_REPO/templates/akofink.zsh-theme" "$HOME/.oh-my-zsh/custom/themes/akofink.zsh-theme"
cp "$DOTS_REPO/templates/.zshrc" "$HOME/.zshrc"

"${SUDO[@]}" chsh -s "$(command -v zsh)" "$USER"
