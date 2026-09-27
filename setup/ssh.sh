#!/usr/bin/env bash

ssh_config_dir="$HOME/.ssh/config.d"
ssh_config="$HOME/.ssh/config"
dots_ssh_config="$ssh_config_dir/dots.conf"
mkdir -p "$ssh_config_dir"
chmod 700 "$HOME/.ssh" "$ssh_config_dir"
eval_template "$DOTS_REPO/templates/ssh/dots.conf" "$dots_ssh_config" ''
chmod 600 "$dots_ssh_config"

if [[ ! -f "$ssh_config" ]]; then
  : > "$ssh_config"
  chmod 600 "$ssh_config"
fi
if ! grep -Fqx 'Include ~/.ssh/config.d/dots.conf' "$ssh_config"; then
  printf '\nInclude ~/.ssh/config.d/dots.conf\n' >> "$ssh_config"
fi
