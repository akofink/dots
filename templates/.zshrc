# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="akofink"

# Enable auto-updating of oh-my-zsh
zstyle ':omz:update' mode auto

# Example aliases
alias l='ls -la'
alias mux=tmuxinator
alias s='source ~/.zshrc'
alias gpullr='git pull --rebase'
alias gpush='git push'
alias :e="vim"
alias v='vim'
alias g='git'

plugins=(gem git rails ruby zsh-autosuggestions)

# rbenv completions need to be on fpath before compinit runs
if [ -d "$HOME/.rbenv/completions" ]; then
  fpath=("$HOME/.rbenv/completions" $fpath)
fi

# Docker Desktop on WSL can leave a broken _docker symlink in the system
# vendor completions directory, which makes compinit error during startup.
if [ -n "$WSL_DISTRO_NAME" ] && [ -L /usr/share/zsh/vendor-completions/_docker ] && [ ! -e /usr/share/zsh/vendor-completions/_docker ]; then
  fpath=(${fpath:#/usr/share/zsh/vendor-completions})
fi

# Tmux Options
export ZSH_TMUX_AUTOCONNECT=false
export ZSH_TMUX_AUTOQUIT=false

if [ -f $ZSH/oh-my-zsh.sh ]; then source $ZSH/oh-my-zsh.sh; fi
if [ -f ~/.secrets ]; then source ~/.secrets; fi # Secret key environment variables
if [ -f ~/.env ]; then source ~/.env; fi # Other environment variables

# Rubygems user binary path setup
if which ruby >/dev/null && which gem >/dev/null; then
    PATH="$(ruby -r rubygems -e 'puts Gem.user_dir')/bin:$PATH"
fi

# Customize to your needs...
export PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/usr/local/git/bin:$PATH
# Atlas CLI env setup
if [ -d /opt/atlassian/bin ]; then
  export PATH=$PATH:/opt/atlassian/bin
fi

# Homebrew env setup
if [ -d /opt/homebrew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# nvm env setup
if [ -d ~/.nvm ]; then
  export NVM_DIR="$HOME/.nvm"
  nvm_node_bins=("$NVM_DIR"/versions/node/*/bin(Nom[1]))
  if [ ${#nvm_node_bins[@]} -gt 0 ]; then
    export PATH="${nvm_node_bins[1]}:$PATH"
  fi
  unset nvm_node_bins

  load_nvm() {
    unset -f nvm node npm npx codex 2>/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" --no-use
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    if [ -z "${NVM_LAZY_LOADED-}" ]; then
      typeset -g NVM_LAZY_LOADED=1
      typeset -f nvm_auto >/dev/null 2>&1 && nvm_auto use >/dev/null 2>&1
    fi
  }
  nvm() { load_nvm; nvm "$@"; }
  node() { load_nvm; node "$@"; }
  npm() { load_nvm; npm "$@"; }
  npx() { load_nvm; npx "$@"; }
  if [ -n "$WSL_DISTRO_NAME" ]; then
    codex() { load_nvm; command codex "$@"; }
  fi
fi

# rbenv
if [ -d ~/.rbenv ]; then
  export PATH="$HOME/.rbenv/bin:$PATH"

  eval "$(~/.rbenv/bin/rbenv init - zsh)"
fi

rbenv_update() {
  git -C "$HOME/.rbenv" pull --ff-only
  git -C "$HOME/.rbenv/plugins/ruby-build" pull --ff-only
}

# pyenv
if [ -d ~/.pyenv ]; then
  eval "$(pyenv init -)"
fi

# goenv
if [ -d ~/.goenv ]; then
  export GOENV_ROOT="$HOME/.goenv"
  export GOENV_PATH_ORDER=front
  export PATH="$GOENV_ROOT/bin:$PATH"
  eval "$(goenv init -)"
fi

if [ -d "$HOME/.sdkman" ]; then
  export SDKMAN_DIR="$HOME/.sdkman"
  [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"
fi

# opencode
if [ -d "$HOME/.opencode/bin" ]; then
  export PATH="$HOME/.opencode/bin:$PATH"
fi

# Local source build of rovodev (patched to keep claude-opus selections).
# Only activated on machines with the acra-python repo checked out (work).
if [ -d "$HOME/dev/repos/atlassian/acra-python" ]; then
  rovodev() {
    local repo="$HOME/dev/repos/atlassian/acra-python"
    local stamp="$repo/.git/.rovodev-last-pull"
    if [[ ! -f "$stamp" || $(( $(date +%s) - $(stat -f %m "$stamp") )) -ge 43200 ]]; then
      (cd "$repo" && git pull --rebase --autostash && uv sync) && touch "$stamp"
    fi
    AUTH_METHOD=oauth uv run --project "$repo" rovodev "$@"
  }
fi
