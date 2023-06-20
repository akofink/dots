#!/usr/bin/env bash

source "$DOTS_REPO/util.sh" # eval_template

eval_template "$DOTS_REPO/templates/.tmux.conf" "$HOME/.tmux.conf"
