#!/usr/bin/env bash

set -ae

if [ "$(basename -- "$0")" != "bootstrap.sh" ]; then
  if [[ -n "${ENV_SETUP_COMPLETE:-}" ]]; then
    return
  fi

  echo "🍄 Setting up common environment variables..."
fi

export DEV_REPOS="${DEV_REPOS:-"$HOME/dev/repos"}"
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

PLATFORM="$(uname)"
export PLATFORM # Linux | Darwin
if [[ "$PLATFORM" == "Darwin" ]]
then
  PKG_MGR=(brew)
  PKG_INDEX_UPDATE_SUBCOMMAND=(update)
  PKG_INSTALL_SUBCOMMAND=(install -q)
  ENVSUBST_PKG=gettext
  # shellcheck disable=SC2034
  VIM_BUILD_DEPS=(gcc make libtool)
  # TMUX_BUILD_DEPS=(autoconf automake bison gcc libevent ncurses pkg-config utf8proc)
  # shellcheck disable=SC2034
  TMUX_BUILD_DEPS=() # rely on homebrew
  # shellcheck disable=SC2034
  RUBY_BUILD_DEPS=()
  PKG_LIST=(make)
  if [[ -n "$ENVSUBST_PKG" ]]; then
    PKG_LIST+=("$ENVSUBST_PKG")
  fi
  if [ ! -f /opt/homebrew/bin/brew ]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ "$PLATFORM" == "Linux" ]]
then
  # shellcheck disable=SC2034
  ZSH_BUILD_DEPS=(zsh)

  # LINUX_COMMON_PKG_LIST=""
  if command -v yum &> /dev/null
  then
    PKG_MGR=("${SUDO[@]}" yum)
    PKG_INDEX_UPDATE_SUBCOMMAND=(check-update)
    PKG_INSTALL_SUBCOMMAND=(install -y)
    ENVSUBST_PKG=gettext-envsubst
    # shellcheck disable=SC2034
    VIM_BUILD_DEPS=(gcc make clang libtool ncurses-devel)
    # shellcheck disable=SC2034
    TMUX_BUILD_DEPS=(autoconf automake bison gcc g++ libevent-devel libncurses-devel locales pkg-config)
    # shellcheck disable=SC2034
    RUBY_BUILD_DEPS=()
    PKG_LIST=(make)
    if [[ -n "$ENVSUBST_PKG" ]]; then
      PKG_LIST+=("$ENVSUBST_PKG")
    fi
  elif command -v apt &> /dev/null
  then
    PKG_MGR=("${SUDO[@]}" apt)
    PKG_INDEX_UPDATE_SUBCOMMAND=(update)
    PKG_INSTALL_SUBCOMMAND=(install -y)
    ENVSUBST_PKG=gettext-base
    # shellcheck disable=SC2034
    VIM_BUILD_DEPS=(autoconf g++ gcc make ncurses-dev libx11-dev libxt-dev libxpm-dev libxmu-dev)
    # shellcheck disable=SC2034
    TMUX_BUILD_DEPS=(autoconf automake bison build-essential libevent-dev libncurses-dev locales pkg-config)
    # shellcheck disable=SC2034
    RUBY_BUILD_DEPS=(git autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev)
    PKG_LIST=(gettext)
    if [[ -n "$ENVSUBST_PKG" ]]; then
      PKG_LIST+=("$ENVSUBST_PKG")
    fi
  elif command -v apk &> /dev/null
  then
    PKG_MGR=("${SUDO[@]}" apk)
    PKG_INDEX_UPDATE_SUBCOMMAND=(update)
    PKG_INSTALL_SUBCOMMAND=(add)
    # shellcheck disable=SC2034
    VIM_BUILD_DEPS=(gcc make clang libtool-bin ncurses-dev)
    # shellcheck disable=SC2034
    TMUX_BUILD_DEPS=(autoconf automake bison build-essential libevent-dev libncurses-dev locales pkg-config)
    # shellcheck disable=SC2034
    RUBY_BUILD_DEPS=()
    ENVSUBST_PKG=gettext
    PKG_LIST=(shadow bash)
    if [[ -n "$ENVSUBST_PKG" ]]; then
      PKG_LIST+=("$ENVSUBST_PKG")
    fi
  else
    fatal "Failed to identify a package manager (yum, apt, apk, ?)"
  fi
fi


export PKG_MGR
export PKG_INSTALL=("${PKG_MGR[@]}" "${PKG_INSTALL_SUBCOMMAND[@]}")
export PKG_INDEX_UPDATE=("${PKG_MGR[@]}" "${PKG_INDEX_UPDATE_SUBCOMMAND[@]}")

set +e

printf 'Running: %s\n' "${PKG_INDEX_UPDATE[*]}"
"${PKG_INDEX_UPDATE[@]}"

set -e

if [[ ${#PKG_LIST[@]} -gt 0 ]]; then
  printf 'Installing: %s %s\n' "${PKG_INSTALL[*]}" "${PKG_LIST[*]}"
  "${PKG_INSTALL[@]}" "${PKG_LIST[@]}"
fi


export ENV_SETUP_COMPLETE=1
#!/usr/bin/env bash

# shellcheck source-path=SCRIPTDIR

err() { echo "$@" 1>&2; }
fatal() { err "$@" 1>&2; exit 1; }

if [[ -n "${UTIL_SETUP_COMPLETE:-}" ]]; then
  return
fi

if [[ -z "${ENV_SETUP_COMPLETE:-}" ]]; then
  script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  if [[ -z "$script_dir" ]]; then
    fatal "Unable to determine util.sh directory"
  fi

  if ! pushd "$script_dir" > /dev/null; then
    fatal "Failed to enter $script_dir"
  fi

  # shellcheck source=setup/env.sh
  source env.sh

  if ! popd > /dev/null; then
    fatal "Failed to return from $script_dir"
  fi
fi

# Returns 0 when an archived copy of the destination already has the same contents.
destination_has_matching_backup() {
  local destination="$1"
  local backup
  for backup in "$destination".old.*; do
    [[ -e "$backup" ]] || continue
    if cmp -s "$destination" "$backup"; then
      return 0
    fi
  done
  return 1
}

# Creates a timestamped backup when no existing archive matches current contents.
backup_destination_if_needed() {
  local destination="$1"

  if destination_has_matching_backup "$destination"; then
    return
  fi

  local timestamp
  timestamp=$(date +%y%m%d%H%M%S) || fatal "Failed to generate backup timestamp"
  mv "$destination" "$destination.old.$timestamp"
}

# eval_template templates/.vimrc.template ~/.vimrc
# Safely applies envsubst
# Archives existing destination files in place by appending a timestamp
# 1: template file
# 2: destination file
eval_template() {
  local template="$1"
  local destination="$2"

  if [[ -z "$destination" ]]; then
    return
  fi

  if ! command -v envsubst &> /dev/null; then
    fatal "No envsubst command found!"
  fi

  local rendered
  rendered=$(mktemp) || fatal "Failed to create temp file for rendering $template"
  # Render the template once so we can compare before overwriting.
  if ! envsubst < "$template" > "$rendered"; then
    rm -f "$rendered"
    fatal "Failed to render template $template"
  fi

  if [[ -f "$destination" ]]; then
    # Nothing to do when the destination already matches the rendered template.
    if cmp -s "$rendered" "$destination"; then
      rm -f "$rendered"
      return
    fi

    # Only archive the current file when its contents are not already preserved.
    backup_destination_if_needed "$destination"
  fi

  if ! cat "$rendered" > "$destination"; then
    rm -f "$rendered"
    fatal "Failed to write rendered template to $destination"
  fi
  rm -f "$rendered"
}

export UTIL_SETUP_COMPLETE=1
#!/usr/bin/env bash

if [[ -n "${GIT_SETUP_COMPLETE:-}" ]]; then
  return
fi

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  source setup/util.sh
fi

command -v git &>/dev/null || "${PKG_INSTALL[@]}" git

export GIT_EMAIL="${GIT_EMAIL:-"ajkofink@gmail.com"}"
export GIT_SIGNINGKEY="${GIT_SIGNINGKEY:-"2C911B0A"}"
export GITHUB_USER="${GITHUB_USER:-"akofink"}"
if [[ -n "$WSL_DISTRO_NAME" ]]; then
  GIT_CREDENTIAL_HELPER=${GIT_CREDENTIAL_HELPER:-"/mnt/c/Program\\\\ Files/Git/mingw64/bin/git-credential-manager.exe"}
elif [[ "$PLATFORM" == "Darwin" ]]; then
  GIT_CREDENTIAL_HELPER=${GIT_CREDENTIAL_HELPER:-"osxkeychain"}
fi
export GIT_CREDENTIAL_HELPER=${GIT_CREDENTIAL_HELPER:-"store"}

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
  git clone https://github.com/akofink/dots.git $DOTS_REPO
fi

eval_template "$DOTS_REPO/templates/.gitignore" "$HOME/.gitignore"
eval_template "$DOTS_REPO/templates/.gitconfig" "$HOME/.gitconfig"

export REPOS_SETUP_COMPLETE=1
(cd "$DOTS_REPO" && ./setup.sh)
