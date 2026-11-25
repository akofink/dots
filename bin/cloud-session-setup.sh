#!/usr/bin/env bash
# Cloud-session setup for the attached repos, runnable by an environment setup script or by
# an agent at session start (idempotent, best effort): link the repos into ~/dev/repos, build
# akagent, expose notes-task/syncdots, turn commit signing off and put ~/.local/bin on PATH.
# With --llm it also runs `setup.sh --only llm` (installs agent CLIs, skills and instruction links).
# Usage: cloud-session-setup.sh [--llm] [attach-root]   (default root detected; see cloud-lib.sh)
set -uo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/cloud-lib.sh"
llm=0
if [[ "${1:-}" == "--llm" ]]; then llm=1; shift; fi
attach_root=$(cloud_attach_root "${1:-}")
status=0

cloud_update_repos "$attach_root"
bash "$script_dir/cloud-link-repos.sh" "$attach_root" || { echo "cloud-link-repos failed" >&2; status=1; }
if [[ "$llm" -eq 1 ]] && [[ -x "$script_dir/../setup.sh" ]]; then
  (cd "$script_dir/.." && ./setup.sh --only llm) || { echo "llm setup failed" >&2; status=1; }
fi
[[ -d "$attach_root/dots/.githooks" ]] && { bash "$script_dir/install-git-hooks.sh" "$attach_root/dots" || status=1; }
# The dots gitconfig template turns on commit signing; cloud sessions have no key.
git config --global commit.gpgsign false
grep -q '.local/bin' ~/.bashrc 2>/dev/null || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "open a new shell or run: export PATH=\"\$HOME/.local/bin:\$PATH\"" ;; esac
exit "$status"
