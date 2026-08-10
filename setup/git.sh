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
