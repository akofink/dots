#!/usr/bin/env bash

set -ae

err() { echo "$@" 1>&2; }
fatal() { err "$@" 1>&2; exit 1; }

current_script_name="$(basename -- "${BASH_SOURCE[0]}")"

if [ "$current_script_name" != "bootstrap.sh" ]; then
  if [[ -n "${ENV_SETUP_COMPLETE:-}" ]]; then
    return
  fi

  echo "🍄 Setting up common environment variables..."
fi

export DEV_REPOS="${DEV_REPOS:-"$HOME/dev/repos"}"
export NOTES_REPO="${NOTES_REPO:-"$DEV_REPOS/notes"}"
export NOTES_REPO_URL="${NOTES_REPO_URL:-"https://github.com/akofink/notes.git"}"

if [ "$current_script_name" = "bootstrap.sh" ]; then
  dots_repo_default="$DEV_REPOS/dots"
else
  env_script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  dots_repo_default=$(cd -- "$env_script_dir/.." && pwd)
fi
export DOTS_REPO="${DOTS_REPO:-"$dots_repo_default"}"

# Keep large installer temp files off tiny tmpfs /tmp mounts, common on small EC2 instances.
export DOTS_SETUP_TMPDIR="${DOTS_SETUP_TMPDIR:-"$HOME/.cache/dots/tmp"}"
mkdir -p "$DOTS_SETUP_TMPDIR"
export TMPDIR="${TMPDIR:-"$DOTS_SETUP_TMPDIR"}"

has_jamf_default=0
if [[ -d /usr/local/jamf ]] || [[ -x /usr/local/bin/jamf ]]; then
  has_jamf_default=1
fi
export HAS_JAMF="${HAS_JAMF:-"$has_jamf_default"}"

# MACHINE_CLASS identifies the role of this machine.
# Current values: "work" | "personal"
# Defaults to "work" on Jamf-managed hosts; override before running setup
# to force a specific class (e.g. MACHINE_CLASS=personal ./setup.sh).
# Avoid adding new behavior gated directly on HAS_JAMF; use MACHINE_CLASS
# instead so the detection logic stays in one place.
_default_machine_class=personal
if is_truthy "${HAS_JAMF}"; then
  _default_machine_class=work
fi
export MACHINE_CLASS="${MACHINE_CLASS:-"$_default_machine_class"}"

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
  # shellcheck disable=SC2034
  TMUX_BUILD_DEPS=(autoconf automake bison gcc libevent ncurses pkgconf utf8proc)
  # shellcheck disable=SC2034
  RUBY_BUILD_DEPS=()
  PKG_LIST=(make ripgrep)
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
    ENVSUBST_PKG=gettext
    # shellcheck disable=SC2034
    VIM_BUILD_DEPS=(gcc make clang libtool ncurses-devel)
    # shellcheck disable=SC2034
    TMUX_BUILD_DEPS=(autoconf automake bison gcc g++ libevent-devel ncurses-devel pkg-config)
    # shellcheck disable=SC2034
    RUBY_BUILD_DEPS=()
    PKG_LIST=(bubblewrap make)
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
    VIM_BUILD_DEPS=(autoconf g++ gcc make ncurses-dev)
    # shellcheck disable=SC2034
    TMUX_BUILD_DEPS=(autoconf automake bison build-essential libevent-dev libncurses-dev locales pkg-config)
    # shellcheck disable=SC2034
    RUBY_BUILD_DEPS=(git autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev)
    PKG_LIST=(gettext ripgrep)
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
    PKG_LIST=(bubblewrap shadow bash ripgrep)
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

if ! command -v rg >/dev/null 2>&1; then
  if [[ "$PLATFORM" == "Linux" ]] && command -v yum >/dev/null 2>&1; then
    ripgrep_version=14.1.1
    case "$(uname -m)" in
      aarch64)
        ripgrep_target=aarch64-unknown-linux-gnu
        ;;
      x86_64)
        ripgrep_target=x86_64-unknown-linux-gnu
        ;;
      *)
        fatal "ripgrep is not packaged and no release is available for $(uname -m)"
        ;;
    esac

    ripgrep_tmp_dir=$(mktemp -d) || fatal "Failed to create a temporary ripgrep directory"
    ripgrep_archive="ripgrep-${ripgrep_version}-${ripgrep_target}.tar.gz"
    ripgrep_url="https://github.com/BurntSushi/ripgrep/releases/download/${ripgrep_version}/${ripgrep_archive}"
    if ! curl -fsSL "$ripgrep_url" -o "$ripgrep_tmp_dir/$ripgrep_archive"; then
      rm -rf "$ripgrep_tmp_dir"
      fatal "Failed to download ripgrep from $ripgrep_url"
    fi
    if ! tar -xzf "$ripgrep_tmp_dir/$ripgrep_archive" -C "$ripgrep_tmp_dir"; then
      rm -rf "$ripgrep_tmp_dir"
      fatal "Failed to unpack ripgrep"
    fi
    mkdir -p "$HOME/.local/bin"
    if ! install -m 0755 "$ripgrep_tmp_dir/ripgrep-${ripgrep_version}-${ripgrep_target}/rg" "$HOME/.local/bin/rg"; then
      rm -rf "$ripgrep_tmp_dir"
      fatal "Failed to install ripgrep"
    fi
    rm -rf "$ripgrep_tmp_dir"
    export PATH="$HOME/.local/bin:$PATH"
  fi
fi

if ! command -v rg >/dev/null 2>&1; then
  fatal "ripgrep did not install rg"
fi

export ENV_SETUP_COMPLETE=1
#!/usr/bin/env bash

# shellcheck source-path=SCRIPTDIR

if ! declare -F err >/dev/null 2>&1; then
  err() { echo "$@" 1>&2; }
fi

if ! declare -F fatal >/dev/null 2>&1; then
  fatal() { err "$@" 1>&2; exit 1; }
fi

if ! declare -F warn >/dev/null 2>&1; then
  warn() { err "$@"; }
fi

if [[ -z "${DOTS_REPO:-}" ]]; then
  util_script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
  DOTS_REPO=$(cd -- "$util_script_dir/.." && pwd)
  export DOTS_REPO
fi

if [[ -n "${UTIL_SETUP_COMPLETE:-}" ]]; then
  return
fi

is_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

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

DOTS_BACKUP_DIR=${DOTS_BACKUP_DIR:-$DOTS_REPO/.backups}
export DOTS_BACKUP_DIR

backup_path_prefix() {
  local destination="$1"
  printf '%s/%s' "$DOTS_BACKUP_DIR" "${destination#/}"
}

# Returns 0 when an archived copy of the destination already has the same contents.
destination_has_matching_backup() {
  local destination="$1"
  local backup
  local backup_prefix
  backup_prefix=$(backup_path_prefix "$destination") || fatal "Failed to determine backup path for $destination"
  for backup in "$backup_prefix".old.*; do
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
  local backup
  backup="$(backup_path_prefix "$destination").old.$timestamp"
  mkdir -p "$(dirname -- "$backup")"
  mv "$destination" "$backup"
}

install_symlink() {
  local source="$1"
  local destination="$2"

  if [[ -z "$source" || -z "$destination" ]]; then
    return
  fi

  if [[ ! -e "$source" ]]; then
    fatal "Cannot symlink missing source: $source"
  fi

  local destination_dir
  destination_dir=$(dirname -- "$destination") || fatal "Failed to determine directory for $destination"
  mkdir -p "$destination_dir"

  if [[ -L "$destination" ]]; then
    local current_target
    current_target=$(readlink "$destination") || fatal "Failed to read symlink $destination"
    if [[ "$current_target" == "$source" ]]; then
      return
    fi
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    local timestamp
    timestamp=$(date +%y%m%d%H%M%S) || fatal "Failed to generate backup timestamp"
    local backup
    backup="$(backup_path_prefix "$destination").old.$timestamp"
    mkdir -p "$(dirname -- "$backup")"
    mv "$destination" "$backup"
  fi

  ln -s "$source" "$destination"
}

remove_symlink_if_points_to() {
  local destination="$1"
  local source_prefix="$2"

  if [[ ! -L "$destination" ]]; then
    return
  fi

  local current_target
  current_target=$(readlink "$destination") || fatal "Failed to read symlink $destination"
  if [[ "$current_target" == "$source_prefix" || "$current_target" == "$source_prefix"/* ]]; then
    rm -f "$destination"
  fi
}

# eval_template templates/.vimrc.template ~/.vimrc
# eval_template templates/.zshrc ~/.zshrc '$GIT_EMAIL $GIT_SIGNINGKEY'
#
# Safely applies envsubst to a template file and installs it at the destination.
# Archives existing destination files in place by appending a timestamp.
#
# 1: template file
# 2: destination file
# 3: (optional) shell-format string of variables to substitute, e.g. '$FOO $BAR'.
#    When provided, only the listed variables are expanded; all other $VAR
#    references are passed through verbatim, which is essential for templates
#    (such as .zshrc) that contain runtime shell variables alongside the
#    setup-time variables being substituted.
#    When omitted, envsubst expands every $VAR in the template.
eval_template() {
  local template="$1"
  local destination="$2"
  local subst_vars="${3:-}"
  local has_subst_vars=0
  if [[ $# -ge 3 ]]; then
    has_subst_vars=1
  fi

  if [[ -z "$destination" ]]; then
    return
  fi

  if ! command -v envsubst &> /dev/null; then
    fatal "No envsubst command found!"
  fi

  local rendered
  rendered=$(mktemp) || fatal "Failed to create temp file for rendering $template"
  # Render the template once so we can compare before overwriting.
  # Pass $subst_vars whenever the caller provides the third argument. An empty
  # string intentionally tells envsubst to substitute nothing at all.
  if [[ $has_subst_vars -eq 1 ]]; then
    if ! envsubst "$subst_vars" < "$template" > "$rendered"; then
      rm -f "$rendered"
      fatal "Failed to render template $template"
    fi
  else
    if ! envsubst < "$template" > "$rendered"; then
      rm -f "$rendered"
      fatal "Failed to render template $template"
    fi
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

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

if command -v rpm &>/dev/null && rpm -q gnupg2-minimal &>/dev/null && ! command -v gpg-agent &>/dev/null; then
  "${PKG_MGR[@]}" swap -y gnupg2-minimal gnupg2
fi

command -v git &>/dev/null || "${PKG_INSTALL[@]}" git

_default_git_email="ajkofink@gmail.com"
_default_github_user="akofink"
_default_github_credential_config=$'[credential "https://github.com"]\n  username = akofink'
if [[ "${MACHINE_CLASS:-personal}" == "work" ]]; then
  _default_git_email="akofink@atlassian.com"
  _default_github_user="akofink-atlassian"
  _default_github_credential_config=""
fi
export GIT_EMAIL="${GIT_EMAIL:-"${_default_git_email}"}"

export GIT_SIGNINGKEY="${GIT_SIGNINGKEY:-"2C911B0A!"}"
export GIT_GPG_PROGRAM="${GIT_GPG_PROGRAM:-"$DOTS_REPO/bin/git-gpg.sh"}"
export GITHUB_USER="${GITHUB_USER:-"${_default_github_user}"}"
export GITHUB_CREDENTIAL_CONFIG="${GITHUB_CREDENTIAL_CONFIG:-"${_default_github_credential_config}"}"
if [[ -n "$WSL_DISTRO_NAME" ]]; then
  GIT_CREDENTIAL_HELPER=${GIT_CREDENTIAL_HELPER:-"/mnt/c/Program\\\\ Files/Git/mingw64/bin/git-credential-manager.exe"}
elif [[ "$PLATFORM" == "Darwin" ]]; then
  GIT_CREDENTIAL_HELPER=${GIT_CREDENTIAL_HELPER:-"osxkeychain"}
fi
export GIT_CREDENTIAL_HELPER=${GIT_CREDENTIAL_HELPER:-"store"}

export GIT_SETUP_COMPLETE=1
#!/usr/bin/env bash

if [[ -n "${REPOS_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${GIT_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/git.sh
  source "$script_dir/git.sh"
fi

mkdir -p "$DEV_REPOS"

if [[ ! -d "$DOTS_REPO" ]]
then
  git clone https://github.com/akofink/dots.git "$DOTS_REPO"
fi

if is_truthy "${SETUP_NOTES_REPO:-1}" && [[ ! -d "$NOTES_REPO" ]]
then
  git clone "$NOTES_REPO_URL" "$NOTES_REPO"
fi

eval_template "$DOTS_REPO/templates/gitignore.template" "$HOME/.gitignore" ''
eval_template "$DOTS_REPO/templates/.gitconfig" "$HOME/.gitconfig"

export REPOS_SETUP_COMPLETE=1
(cd "$DOTS_REPO" && ./setup.sh)
