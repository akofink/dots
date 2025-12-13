#!/usr/bin/env bash

if [[ -n "${GIT_SETUP_COMPLETE:-}" ]]; then
  return
fi

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  source setup/util.sh
fi

command -v git &>/dev/null || "${PKG_INSTALL[@]}" git

_default_git_email="ajkofink@gmail.com"
if { [[ -d /usr/local/jamf ]] || [[ -x /usr/local/bin/jamf ]] ; }; then
  _default_git_email="akofink@atlassian.com"
fi
export GIT_EMAIL="${GIT_EMAIL:-"${_default_git_email}"}"

export GIT_SIGNINGKEY="${GIT_SIGNINGKEY:-"2C911B0A"}"
export GITHUB_USER="${GITHUB_USER:-"akofink"}"
if [[ -n "$WSL_DISTRO_NAME" ]]; then
  GIT_CREDENTIAL_HELPER=${GIT_CREDENTIAL_HELPER:-"/mnt/c/Program\\\\ Files/Git/mingw64/bin/git-credential-manager.exe"}
elif [[ "$PLATFORM" == "Darwin" ]]; then
  GIT_CREDENTIAL_HELPER=${GIT_CREDENTIAL_HELPER:-"osxkeychain"}
fi
export GIT_CREDENTIAL_HELPER=${GIT_CREDENTIAL_HELPER:-"store"}

export GIT_SETUP_COMPLETE=1
