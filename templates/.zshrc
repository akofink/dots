# motd

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

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(tmux tmuxinator gem git rails ruby zsh-autosuggestions)

# Tmux Options
export ZSH_TMUX_AUTOCONNECT=false
export ZSH_TMUX_AUTOQUIT=false

if [ -f $ZSH/oh-my-zsh.sh ]; then source $ZSH/oh-my-zsh.sh; fi
if [ -f ~/.secrets ]; then source ~/.secrets; fi # Secret key environment variables
if [ -f ~/.env ]; then source ~/.env; fi # Other environment variables

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

export GOPATH=$HOME/go

# Tmuxinator
[[ -s $HOME/.tmuxinator/scripts/tmuxinator ]] && source $HOME/.tmuxinator/scripts/tmuxinator

export EDITOR=nvim
git config --global user.email $GIT_EMAIL >/dev/null

export DISPLAY=:0
export GPG_TTY=$(tty)
