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
alias l='la -la'
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
export PATH=/Users/akofink/bin:/usr/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/usr/local/git/bin:$PATH
[ -f $HOME/.cargo/env ] && source $HOME/.cargo/env

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
  load_nvm() {
    unset -f nvm node npm npx
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
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
if [ -d ~/.pyenv ]; then
  eval "$(pyenv init -)"
fi

# goenv
if [ -d ~/.goenv ]; then
  export GOENV_ROOT="$HOME/.goenv"
  export PATH="$GOENV_ROOT/bin:$PATH"
  eval "$(goenv init -)"
fi

export GOPATH=$HOME/go

# Tmuxinator
[[ -s $HOME/.tmuxinator/scripts/tmuxinator ]] && source $HOME/.tmuxinator/scripts/tmuxinator

export EDITOR=vim
git config --global user.email $GIT_EMAIL >/dev/null

export DISPLAY=:0
export GPG_TTY=$(tty)

# libpq from homebrew
if [ -d /opt/homebrew/opt/libpq ]; then
  export PATH="/opt/homebrew/opt/libpq/bin:$PATH"
fi
