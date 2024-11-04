#!/usr/bin/env bash

set -ae

if [ "$(basename -- "$0")" != "bootstrap.sh" ]; then
  if [ $ENV_SETUP_COMPLETE ]; then
    return
  fi

  echo "🍄 Setting up common environment variables..."
fi

export DEV_REPOS=${DEV_REPOS:-"$HOME/dev/repos"}
export DOTS_REPO="$DEV_REPOS/dots"

# Ensure USER
if [[ -z "${USER-}" ]]
then
  USER="$(id -un)"
  export USER
fi

# Set SUDO if non-root
if [[ "$USER" == "root" ]]
then
  SUDO=()
else
  SUDO=(sudo)
fi
export SUDO

export PLATFORM="$(uname)" # Linux | Darwin
if [[ "$PLATFORM" == "Darwin" ]]
then
  PKG_MGR=(brew)
  PKG_INDEX_UPDATE_SUBCOMMAND="update"
  PKG_INSTALL_SUBCOMMAND=(install -q)
  ENVSUBST_PKG=gettext
  VIM_BUILD_DEPS=(gcc make libtool)
  # TMUX_BUILD_DEPS=(autoconf automake bison gcc libevent ncurses pkg-config utf8proc)
  TMUX_BUILD_DEPS=() # rely on homebrew
  PKG_LIST=(make $ENVSUBST_PKG)
  if [ ! -f /opt/homebrew/bin/brew ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ "$PLATFORM" == "Linux" ]]
then
  ZSH_BUILD_DEPS=(zsh)

  # LINUX_COMMON_PKG_LIST=""
  if command -v yum &> /dev/null
  then
    PKG_MGR=($SUDO yum)
    PKG_INDEX_UPDATE_SUBCOMMAND=(check-update)
    PKG_INSTALL_SUBCOMMAND=(install -y)
    ENVSUBST_PKG=gettext-envsubst
    VIM_BUILD_DEPS=(gcc make clang libtool ncurses-devel)
    TMUX_BUILD_DEPS=(autoconf automake bison gcc g++ libevent-devel libncurses-devel locales pkg-config)
    PKG_LIST=(make $ENVSUBST_PKG)
  elif command -v apt &> /dev/null
  then
    PKG_MGR=($SUDO apt)
    PKG_INDEX_UPDATE_SUBCOMMAND=(update)
    PKG_INSTALL_SUBCOMMAND=(install -y)
    ENVSUBST_PKG=gettext-base
    VIM_BUILD_DEPS=(autoconf g++ gcc make ncurses-dev)
    TMUX_BUILD_DEPS=(autoconf automake bison build-essential libevent-dev libncurses-dev locales pkg-config)
    PKG_LIST=(gettext $ENVSUBST_PKG)
  elif command -v apk &> /dev/null
  then
    PKG_MGR=($SUDO apk)
    PKG_INDEX_UPDATE_SUBCOMMAND=(update)
    PKG_INSTALL_SUBCOMMAND=(add)
    VIM_BUILD_DEPS=(gcc make clang libtool-bin ncurses-dev)
    TMUX_BUILD_DEPS=(autoconf automake bison build-essential libevent-dev libncurses-dev locales pkg-config)
    ENVSUBST_PKG=gettext
    PKG_LIST=(shadow $ENVSUBST_PKG)
  else
    fatal "Failed to identify a package manager (yum, apt, apk, ?)"
  fi
fi


export PKG_MGR
export PKG_INSTALL=(${PKG_MGR[@]} ${PKG_INSTALL_SUBCOMMAND[@]})
export PKG_INDEX_UPDATE=(${PKG_MGR[@]} ${PKG_INDEX_UPDATE_SUBCOMMAND[@]})

set +e

echo ${PKG_INDEX_UPDATE[@]}
${PKG_INDEX_UPDATE[@]}

set -e

echo ${PKG_INSTALL[@]} ${PKG_LIST[@]}
${PKG_INSTALL[@]} ${PKG_LIST[@]}


export ENV_SETUP_COMPLETE=1
#!/usr/bin/env bash

if [ $UTIL_SETUP_COMPLETE ]; then
  return
fi

if [ ! $ENV_SETUP_COMPLETE ]; then
  source setup/env.sh
fi

err() { echo "$@" 1>&2; }
fatal() { err "$@" 1>&2; exit 1; }

# eval_template templates/.vimrc.template ~/.vimrc
# Safely applies envsubst
# Archives existing destination files in place by appending a timestamp
# 1: template file
# 2: destination file
eval_template() {
  if [[ ! -z $2 ]]
  then
    if [[ -f "$2" ]]
    then
      mv "$2" "$2.old.$(date +%y%m%d%H%M%S)"
    fi
    if ! command -v envsubst &> /dev/null
    then
      fatal "No envsubst command found!"
    fi
    cat "$1" | envsubst > "$2"
  fi
}

export UTIL_SETUP_COMPLETE=1
#!/usr/bin/env bash

if [ $GIT_SETUP_COMPLETE ]; then
  return
fi

if [ ! $UTIL_SETUP_COMPLETE ]; then
  source setup/util.sh
fi

command -v git &>/dev/null || ${PKG_INSTALL[@]} git

export GIT_EMAIL=${GIT_EMAIL:-"ajkofink@gmail.com"}
export GIT_SIGNINGKEY=${GIT_SIGNINGKEY:-"2C911B0A"}
export GITHUB_USER=${GITHUB_USER:-"akofink"}
if [ ! -z "$WSL_DISTRO_NAME" ]; then
  GIT_CREDENTIAL_HELPER=${GIT_CREDENTIAL_HELPER:-"/mnt/c/Program\\\\ Files/Git/mingw64/bin/git-credential-manager.exe"}
elif [ "$PLATFORM" == "Darwin" ]; then
  GIT_CREDENTIAL_HELPER=${GIT_CREDENTIAL_HELPER:-"osxkeychain"}
fi
export GIT_CREDENTIAL_HELPER=${GIT_CREDENTIAL_HELPER:-"store"}

eval_template "$DOTS_REPO/templates/.gitignore" "$HOME/.gitignore"
eval_template "$DOTS_REPO/templates/.gitconfig" "$HOME/.gitconfig"

export GIT_SETUP_COMPLETE=1
#!/usr/bin/env bash


if [ $REPOS_SETUP_COMPLETE ]; then
  return
fi

if [ ! $GIT_SETUP_COMPLETE ]; then
  source setup/git.sh
fi

mkdir -p "$DEV_REPOS"

if [[ ! -d "$DOTS_REPO" ]]
then
  if [[ -d "/app" ]] # For local testing in docker (see Dockerfile)
  then
    ln -s /app $DOTS_REPO
  else
    git clone https://github.com/akofink/dots.git $DOTS_REPO
  fi
fi


export REPOS_SETUP_COMPLETE=1
(cd $DOTS_REPO && source setup.sh)
