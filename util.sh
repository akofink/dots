#!/usr/bin/env bash

# eval_template templates/.vimrc.template ~/.vimrc
# 1: template file
# 2: destination file
eval_template() {
  if [[ ! -z $2 ]]
  then
    if [[ -f "$2" ]]
    then
      mv "$2" "$2.$(date +%y%m%d%H%M%S)"
    fi
    eval "cat <<EOF
      $(<$1)
    EOF" > "$2"
  fi
}
