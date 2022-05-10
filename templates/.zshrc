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
alias server='bundle exec rails s -p 8080'
alias console='bundle exec rails c'
alias black='open http://black.akofink.com'
alias s='source ~/.zshrc'
alias es='vi ~/.zshrc'
alias gpom='git push origin master'
alias gpullr='git pull --rebase'
alias gpush='git push'
alias gt="git commit -m 'task#$TASK' -e" # Commit with tempus task number appended
alias 8080to80="sudo ipfw add 100 fwd 127.0.0.1,8080 tcp from any to me 80"
alias :e="vim"
alias tmux="tmux -2"
alias ktmux='tmux kill-server'
alias timestamp="ruby -e 'print Time.now.strftime(\"%Y%m%d_%H%M%S\")'"
alias v='vim'
alias g='git'
alias be='bundle exec'
alias rakedb='bundle exec rake db:drop db:create db:migrate db:seed'
alias akkit="ssh akkit.akofink.com"
alias pi="ssh pi.akofink.com"
alias shuf="perl -MList::Util=shuffle -e 'print shuffle(<STDIN>);'"
alias ipaddr='ifconfig | ag "(\d+\.)+\d+"'

# Uncomment following line if you want red dots to be displayed while waiting for completion
# COMPLETION_WAITING_DOTS="true"

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
plugins=(tmux tmuxinator gem osx brew git rails ruby zsh-autosuggestions)

# Tmux Options
export ZSH_TMUX_AUTOCONNECT=false
export ZSH_TMUX_AUTOQUIT=false

source $ZSH/oh-my-zsh.sh
source ~/.secrets # Secret key environment variables
source ~/.env # Other environment variables

# Customize to your needs...
export PATH=/usr/local/heroku/bin:/Users/akofink/bin:/usr/local/sbin:/usr/local/bin:/usr/local/mysql/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/usr/local/git/bin:./PATH
source $HOME/.cargo/env

export GOPATH=$HOME/go

# Tmuxinator
[[ -s $HOME/.tmuxinator/scripts/tmuxinator ]] && source $HOME/.tmuxinator/scripts/tmuxinator

export EDITOR=vim
git config --global user.email $GIT_EMAIL

export DISPLAY=:0
export GPG_TTY=$(tty)
