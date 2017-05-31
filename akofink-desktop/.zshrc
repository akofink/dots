# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
ZSH_THEME="tjkirch"

# Example aliases
alias mux=tmuxinator
alias server='bundle exec rails s -p 8080'
alias console='bundle exec rails c'
alias s='source ~/.zshrc'
alias es='vi ~/.zshrc'
alias gpom='git push origin master'
alias gpullr='git pull --rebase'
alias gpush='git push'
alias :e="vim"
alias tmux="TERM=screen-256color-bce tmux"
alias ktmux='tmux kill-server'
alias timestamp="ruby -e 'print Time.now.strftime(\"%Y%m%d_%H%M%S\")'"
alias v='vim'
alias g='git'
alias be='bundle exec'
alias hh='be hammer'
alias rakedb='bundle exec rake db:drop db:create db:migrate db:seed'
alias ipaddr='ifconfig | ag "(\d+\.)+\d+"'
alias vag='vagrant'
alias pullall='~/dev/pull_all.sh'

# Uncomment following line if you want red dots to be displayed while waiting for completion
COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(bundler web-search tmux tmuxinator cap gem git rails ruby)

# Tmux Options
export ZSH_TMUX_AUTOCONNECT=false
export ZSH_TMUX_AUTOQUIT=false

source $ZSH/oh-my-zsh.sh
source ~/.secrets # Secret key environment variables
source ~/.env # Other environment variables

alias l='la -lahZ'

# Tmuxinator
[[ -s $HOME/.tmuxinator/scripts/tmuxinator ]] && source $HOME/.tmuxinator/scripts/tmuxinator

export PATH=/usr/bin:$PATH

export EDITOR=vim
git config --global user.email $GIT_EMAIL
DISABLE_AUTO_TITLE=true

# export PATH="$HOME/.rbenv/bin:$PATH"
# eval "$(rbenv init -)"

export FOREMAN_URL=http://localhost:3000
export FOREMAN_SSL_VERIFY="False"

vagrant() { if [[ $@ == "destroy" ]]; then echo "Disabled for safety!"; else command vagrant "$@"; fi; }
