#!/usr/bin/env bash

if [[ -n "${HTTP_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

install_httpie_from_pip() {
  if ! command -v python3 >/dev/null 2>&1 || ! python3 -m pip --version >/dev/null 2>&1; then
    fatal "Python 3 with pip is required to install HTTPie on yum-based Linux"
  fi
  python3 -m pip install --user --upgrade httpie || fatal "Failed to install HTTPie with pip"
  export PATH="$HOME/.local/bin:$PATH"
}

if [[ "$PLATFORM" == "Linux" ]] && command -v yum >/dev/null 2>&1; then
  # Amazon Linux does not package HTTPie or pip, but includes pip with Python.
  install_httpie_from_pip
else
  "${PKG_INSTALL[@]}" httpie
fi

install_xh_from_release() {
  local installer
  installer=$(mktemp) || fatal "Failed to create a temporary xh installer"
  if ! curl -fsSL https://raw.githubusercontent.com/ducaale/xh/master/install.sh > "$installer"; then
    rm -f "$installer"
    fatal "Failed to download the xh installer"
  fi
  chmod +x "$installer"
  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
  if ! XH_BINDIR="$HOME/.local/bin" "$installer"; then
    rm -f "$installer"
    fatal "Failed to install xh"
  fi
  rm -f "$installer"
}

if [[ "$PLATFORM" == "Darwin" ]]; then
  "${PKG_INSTALL[@]}" xh
elif ! command -v xh >/dev/null 2>&1 || ! command -v xhs >/dev/null 2>&1; then
  # xh is only packaged by newer Debian and Ubuntu releases. Use its official
  # release installer elsewhere so older Linux distributions get both binaries.
  if command -v apt-cache >/dev/null 2>&1 && apt-cache show xh >/dev/null 2>&1; then
    "${PKG_INSTALL[@]}" xh
  else
    install_xh_from_release
  fi
fi

if ! command -v http >/dev/null 2>&1 || ! command -v https >/dev/null 2>&1; then
  fatal "HTTPie did not install http and https"
fi
if ! command -v xh >/dev/null 2>&1 || ! command -v xhs >/dev/null 2>&1; then
  fatal "xh did not install xh and xhs"
fi

export HTTP_SETUP_COMPLETE=1
