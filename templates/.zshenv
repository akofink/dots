[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Discard versioned Homebrew zsh function paths inherited from old shells. Brew
# cleanup removes those Cellar directories during zsh upgrades, which breaks
# autoloaded functions such as compinit, add-zsh-hook, and colors.
if [ -d /opt/homebrew/opt/zsh/share/zsh/functions ]; then
  fpath=(${fpath:#/opt/homebrew/Cellar/zsh/*/share/zsh/functions})
  fpath+=(/opt/homebrew/opt/zsh/share/zsh/functions)
fi

export EDITOR=vim

export GOPATH=$HOME/go
export PATH="$GOPATH/bin:$PATH"

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"

# Ubuntu runs compinit from /etc/zsh/zshrc before ~/.zshrc unless this is set.
# Only disable the global invocation under WSL, where Docker Desktop can
# leave a broken vendor completion symlink behind.
if [ -n "$WSL_DISTRO_NAME" ]; then
  skip_global_compinit=1
fi
