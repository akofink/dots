#!/usr/bin/env bash

if [[ -z "${REPOS_SETUP_COMPLETE:-}" ]]; then
  source setup/repos.sh
fi

# Copy over config templates (.vimrc + .vim/*)
eval_template "$DOTS_REPO/templates/.vimrc" "$HOME/.vimrc"
[[ -d "$HOME/.vim" ]] || mkdir -p "$HOME/.vim"
for f in "$DOTS_REPO"/templates/dot_vim/*; do
  [[ -e "$f" ]] || continue
  eval_template "$f" "$HOME/.vim/$(basename -- "$f")"
done

# Clone vim upstream
if [[ ! -d "$HOME/dev/repos/vim" ]]; then
  mkdir -p "$HOME/dev/repos"
  git clone -q https://github.com/vim/vim.git "$HOME/dev/repos/vim"
fi

# Pull latest vim
(cd "$HOME/dev/repos/vim" && git pull -q)

vim_needs_rebuild() {
  local vim_path
  vim_path=$(command -v vim || true)

  # Build when vim is missing.
  if [[ -z "$vim_path" ]]; then
    return 0
  fi

  # Build when the executable is older than roughly one week.
  local is_week_old
  is_week_old=$(find "$vim_path" -mtime +6 -print -quit 2>/dev/null || true)
  if [[ -n "$is_week_old" ]]; then
    return 0
  fi

  return 1
}

has_x11_headers() {
  # Check for X11 headers in common locations
  local x11_include_paths=(
    "/usr/include/X11/Xlib.h"
    "/usr/local/include/X11/Xlib.h"
    "/opt/X11/include/X11/Xlib.h"
  )
  
  for path in "${x11_include_paths[@]}"; do
    if [[ -f "$path" ]]; then
      return 0
    fi
  done
  
  return 1
}

build_vim() {
  (
    # Determine X11 support
    local vim_configure_flags=(
      --with-features=huge
      --enable-multibyte
      --enable-python3interp
      --enable-terminal
      --enable-cscope
      --prefix=/usr/local
    )
    
    local build_deps=("${VIM_BUILD_DEPS[@]}")
    
    if has_x11_headers; then
      echo "X11 headers detected, enabling X11 support..."
      vim_configure_flags+=(--with-x)
      # Add X11 build dependencies if not already included
      if [[ "${PLATFORM}" == "Linux" ]] && command -v apt &> /dev/null; then
        build_deps+=(libx11-dev libxt-dev libxpm-dev libxmu-dev)
      fi
    else
      echo "X11 headers not found, building without X11 support..."
      vim_configure_flags+=(--without-x)
    fi
    
    "${PKG_INSTALL[@]}" "${build_deps[@]}"
    cd "$HOME/dev/repos/vim" || exit 1

    # Start from a clean tree so configure picks up new flags.
    make distclean >/dev/null 2>&1 || true

    ./configure "${vim_configure_flags[@]}"

    make && "${SUDO[@]}" make install
  )
}

# Build vim from source
if vim_needs_rebuild; then
  build_vim
fi

# Install vim-plug
if [[ ! -f "$HOME/.vim/autoload/plug.vim" ]]; then
  curl -fLo "$HOME/.vim/autoload/plug.vim" --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi
