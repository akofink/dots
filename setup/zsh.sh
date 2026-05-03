#!/usr/bin/env bash

if [[ -n "${ZSH_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${REPOS_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/repos.sh
  source "$script_dir/repos.sh"
fi

if [[ ${#ZSH_BUILD_DEPS[@]} -gt 0 ]]; then
  "${PKG_INSTALL[@]}" "${ZSH_BUILD_DEPS[@]}"
fi

# oh-my-zsh
OH_MY_ZSH_DIR="$HOME/.oh-my-zsh"
OH_MY_ZSH_FETCH_HEAD="$OH_MY_ZSH_DIR/.git/FETCH_HEAD"
if [ -f "$OH_MY_ZSH_FETCH_HEAD" ] && [ -n "$(find "$OH_MY_ZSH_FETCH_HEAD" -mtime +30 -print -quit)" ]; then
  rm -rf "$OH_MY_ZSH_DIR"
fi

if [ ! -d "$OH_MY_ZSH_DIR/lib" ]; then
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
eval_template "$DOTS_REPO/templates/.zshenv" "$HOME/.zshenv"
# Only $GIT_EMAIL is a setup-time variable; all other $VAR references in
# .zshrc (e.g. $HOME, $PATH, $NVM_DIR) are runtime shell variables and must
# be passed through verbatim.
eval_template "$DOTS_REPO/templates/.zshrc" "$HOME/.zshrc" '$GIT_EMAIL'

"${SUDO[@]}" chsh -s "$(command -v zsh)" "$USER"

export ZSH_SETUP_COMPLETE=1
