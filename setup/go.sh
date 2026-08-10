#!/usr/bin/env bash

if [[ -n "${GO_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

export GOENV_ROOT="${GOENV_ROOT:-$HOME/.goenv}"
export GO_VERSION="${GO_VERSION:-1.25.9}"
goenvrc="$HOME/.goenvrc"

export GOENV_PATH_ORDER=front
if [[ -f "$goenvrc" ]] && grep -q '^export GOENV_PATH_ORDER=' "$goenvrc"; then
  if ! grep -q '^export GOENV_PATH_ORDER=front$' "$goenvrc"; then
    goenvrc_tmp=$(mktemp) || fatal "Failed to create temp file for $goenvrc"
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        export\ GOENV_PATH_ORDER=*)
          printf '%s\n' 'export GOENV_PATH_ORDER=front'
          ;;
        *)
          printf '%s\n' "$line"
          ;;
      esac
    done < "$goenvrc" > "$goenvrc_tmp"
    mv "$goenvrc_tmp" "$goenvrc"
  fi
else
  if [[ -s "$goenvrc" ]]; then
    printf '\nexport GOENV_PATH_ORDER=front\n' >> "$goenvrc"
  else
    printf 'export GOENV_PATH_ORDER=front\n' >> "$goenvrc"
  fi
fi

if [[ ! -d "$GOENV_ROOT/.git" ]]; then
  git clone -q https://github.com/go-nv/goenv.git "$GOENV_ROOT"
else
  git -C "$GOENV_ROOT" pull -q --ff-only
fi

export PATH="$GOENV_ROOT/bin:$PATH"
eval "$(goenv init -)"

go_version_dir="$GOENV_ROOT/versions/$GO_VERSION"
goenv_install_args=(-s)
if [[ -d "$go_version_dir/src" ]] && find "$go_version_dir/src" -type f -name '*.go' ! -path '*/testdata/*' -size 0c -print -quit | grep -q .; then
  echo "Detected an incomplete Go $GO_VERSION installation; repairing..."
  goenv_install_args=(-f)
fi
if ! goenv install "${goenv_install_args[@]}" "$GO_VERSION"; then
  fatal "Failed to install Go $GO_VERSION"
fi
goenv global "$GO_VERSION"

if ! command -v go >/dev/null 2>&1; then
  fatal "go not found after installation"
fi

mkdir -p "$HOME/go/bin"
export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$GOPATH/bin:$PATH"

export GO_SETUP_COMPLETE=1
