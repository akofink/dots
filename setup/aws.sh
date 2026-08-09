#!/usr/bin/env bash

if [[ -n "${AWS_SETUP_COMPLETE:-}" ]]; then
  return
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if [[ -z "${UTIL_SETUP_COMPLETE:-}" ]]; then
  # shellcheck source=setup/util.sh
  source "$script_dir/util.sh"
fi

if ! command -v aws >/dev/null 2>&1 || ! command -v aws_completer >/dev/null 2>&1; then
  aws_install_script=$(mktemp) || fatal "Failed to create a temporary AWS CLI installer"
  cleanup_aws_install_script() {
    rm -f "$aws_install_script"
  }
  trap cleanup_aws_install_script RETURN

  if ! curl -fsSL https://awscli.amazonaws.com/v2/install.sh -o "$aws_install_script"; then
    fatal "Failed to download the AWS CLI installer"
  fi
  if ! bash "$aws_install_script"; then
    fatal "Failed to install the AWS CLI"
  fi
  export PATH="$HOME/.local/bin:$PATH"
fi

if ! command -v aws >/dev/null 2>&1; then
  fatal "AWS CLI installer did not install aws"
fi
if ! command -v aws_completer >/dev/null 2>&1; then
  fatal "AWS CLI installer did not install aws_completer"
fi

export AWS_SETUP_COMPLETE=1
