#!/usr/bin/env bash

if [ ! $REPOS_SETUP_COMPLETE ]; then
  source setup/repos.sh
fi

${PKG_INSTALL[@]} ${ZSH_BUILD_DEPS[@]}

# oh-my-zsh
if [ ! -d ~/.oh-my-zsh/lib ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

# oh-my-zsh plugins
ZSH_CUSTOM_PLUGIN_DIR=${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins
if [ ! -d $ZSH_CUSTOM_PLUGIN_DIR/zsh-autosuggestions ]; then
  git clone https://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM_PLUGIN_DIR/zsh-autosuggestions
fi

mkdir -p "$HOME/.oh-my-zsh/custom/themes/"
cp "$DOTS_REPO/templates/akofink.zsh-theme" "$HOME/.oh-my-zsh/custom/themes/akofink.zsh-theme"
cp "$DOTS_REPO/templates/.zshrc" "$HOME/.zshrc"

sudo chsh -s $(which zsh) $USER
