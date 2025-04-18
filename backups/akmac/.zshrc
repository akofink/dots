# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="akofink"

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
export PATH=/usr/local/heroku/bin:/Users/akofink/bin:/usr/local/sbin:/usr/local/bin:/usr/local/mysql/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/usr/local/git/bin:./PATH
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
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
fi

# rbenv
if [ -d ~/.rbenv ]; then
  export PATH=~/.rbenv/bin:"$PATH"

  eval "$(~/.rbenv/bin/rbenv init - zsh)"
  FPATH=~/.rbenv/completions:"$FPATH"
fi

rbenv_update() {
  git -C "$HOME/.rbenv" pull --ff-only
  git -C "$HOME/.rbenv/plugins/ruby-build" pull --ff-only
}

# pyenv
if [ -d ~/.pyenv ]; then
  export PATH=$PATH:~/.pyenv/bin
  eval "$(~/.pyenv/bin/pyenv init -)"
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
