#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
llm_setup="$repo_root/setup/llm.sh"

rg -q 'https://pi\.dev/install\.sh' "$llm_setup"
rg -q 'managed-install\.json' "$llm_setup"
rg -q 'PATH="\$installer_bin:/usr/bin:/bin:/usr/sbin:/sbin" sh "\$install_script"' "$llm_setup"
rg -q 'ln -s "\$node_path" "\$installer_bin/node"' "$llm_setup"
rg -q 'ln -s "\$npm_path" "\$installer_bin/npm"' "$llm_setup"
if rg -q 'install_npm_cli "Pi Coding Agent"' "$llm_setup"; then
  echo 'Pi must not be installed from an unpinned global npm range' >&2
  exit 1
fi

printf 'pi-managed-install-test: ok\n'
