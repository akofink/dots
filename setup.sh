#!/usr/bin/env bash

echo
echo "🍄 Dots setup.sh started..."

if [ ! $REPOS_SETUP_COMPLETE ]; then
  source setup/repos.sh
fi

# for script in $DOTS_REPO/setup/{vim,tmux,zsh,rbenv,tmuxinator}.sh; do
#   if [ -f $script ]; then
#     echo
#     echo "🍄 Running $script"
#     source $script || (echo "💩 Error running script $script"; exit 1)
#   else
#     echo "💩 Error - script does not exist: $script"
#   fi
# done

echo
echo "🎉🎉🎉🎉 Dots setup.sh success! 🎉🎉🎉🎉"
echo
