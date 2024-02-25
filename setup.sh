#!/usr/bin/env bash

echo
echo "🍄 Dots setup.sh started..."

# DEFAULT_PKGS=(${DEFAULT_PKGS:-tmux gpg nodejs zsh curl})

# $PKG_INDEX_UPDATE
# $PKG_INSTALL $DEFAULT_PKGS $LINUX_COMMON_PKG_LIST $PKG_LIST

# NB: Order matters
# for script in $DOTS_REPO/setup/{repos,vim,gpg,zsh,tmux,rbenv,tmuxinator}.sh; do
for script in $DOTS_REPO/setup/{env,repos}.sh; do
  if [ -f $script ]; then
    echo
    echo "🍄 Running $script"
    # source $script
  else
    echo "Error - script does not exist: $script"
  fi
done

echo
echo "🎉🎉🎉🎉 Dots setup.sh success! 🎉🎉🎉🎉"
echo
