#!/usr/bin/env bash

if [ ! $ENV_SETUP_COMPLETE ]; then
  source setup/env.sh
fi

if [ $UTIL_SETUP_COMPLETE ]; then
  return
fi

err() { echo "$@" 1>&2; }
fatal() { err "$@" 1>&2; exit 1; }

# eval_template templates/.vimrc.template ~/.vimrc
# Safely applies envsubst
# Archives existing destination files in place by appending a timestamp
# 1: template file
# 2: destination file
eval_template() {
  if [[ ! -z $2 ]]
  then
    if [[ -f "$2" ]]
    then
      mv "$2" "$2.old.$(date +%y%m%d%H%M%S)"
    fi
    if ! command -v envsubst &> /dev/null
    then
      fatal "No envsubst command found!"
    fi
    cat "$1" | envsubst > "$2"
  fi
}

export UTIL_SETUP_COMPLETE=1
