[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Keep machine role outside synchronized dotfiles so personal machines are not
# classified as work when they use the same templates.
machine_env_file="${DOTS_MACHINE_ENV_FILE:-$HOME/.config/dots/machine.env}"
if [[ -r "$machine_env_file" ]]; then
  source "$machine_env_file"
fi
unset machine_env_file

# Discard versioned Homebrew zsh function paths inherited from old shells. Brew
# cleanup removes those Cellar directories during zsh upgrades, which breaks
# autoloaded functions such as compinit, add-zsh-hook, and colors.
if [ -d /opt/homebrew/opt/zsh/share/zsh/functions ]; then
  fpath=(${fpath:#/opt/homebrew/Cellar/zsh/*/share/zsh/functions})
  fpath+=(/opt/homebrew/opt/zsh/share/zsh/functions)
fi

export EDITOR=vim

export PATH="$HOME/.local/bin:$PATH"

export GOPATH=$HOME/go
export PATH="$GOPATH/bin:$PATH"

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"

# Default nvm Node bin for non-interactive shells (SSH, tmux).
# Do not source nvm.sh here; it is too heavy for every zsh invocation.
export NVM_DIR="$HOME/.nvm"
if [[ -d "$NVM_DIR/versions/node" ]]; then
  nvm_alias_name=default
  nvm_alias_target=
  while [[ -r "$NVM_DIR/alias/$nvm_alias_name" ]]; do
    nvm_alias_target=${$(<"$NVM_DIR/alias/$nvm_alias_name")%%$'\n'*}
    nvm_alias_target=${nvm_alias_target%%[[:space:]]#}
    [[ -z "$nvm_alias_target" || "$nvm_alias_target" == "$nvm_alias_name" ]] && break
    nvm_alias_name=$nvm_alias_target
  done
  if [[ -d "$NVM_DIR/versions/node/$nvm_alias_name/bin" ]]; then
    export PATH="$NVM_DIR/versions/node/$nvm_alias_name/bin:$PATH"
  else
    nvm_node_bins=("$NVM_DIR"/versions/node/*/bin(N[1]))
    if (( ${#nvm_node_bins[@]} > 0 )); then
      export PATH="${nvm_node_bins[1]}:$PATH"
    fi
    unset nvm_node_bins
  fi
  unset nvm_alias_name nvm_alias_target
fi

# Ubuntu runs compinit from /etc/zsh/zshrc before ~/.zshrc unless this is set.
# Only disable the global invocation under WSL, where Docker Desktop can
# leave a broken vendor completion symlink behind.
if [ -n "$WSL_DISTRO_NAME" ]; then
  skip_global_compinit=1
fi
