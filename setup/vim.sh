#!/usr/bin/env bash

if [[ -z "${REPOS_SETUP_COMPLETE:-}" ]]; then
  source setup/repos.sh
fi

# Copy over config templates (.vimrc + .vim/*)
eval_template "$DOTS_REPO/templates/.vimrc" "$HOME/.vimrc"
[[ -d "$HOME/.vim" ]] || mkdir -p "$HOME/.vim"
for f in "$DOTS_REPO"/templates/.vim/*; do
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

build_vim() {
  (
    "${PKG_INSTALL[@]}" "${VIM_BUILD_DEPS[@]}"
    cd "$HOME/dev/repos/vim" || exit 1

    # Start from a clean tree so configure picks up new flags.
    make distclean >/dev/null 2>&1 || true

    ./configure \
      --with-features=huge \
      --enable-multibyte \
      --enable-python3interp \
      --enable-terminal \
      --enable-cscope \
      --with-x \
      --prefix=/usr/local

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
