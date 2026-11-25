#!/usr/bin/env bash
# Cloud-session setup: link repos attached at /home/user/<repo> into ~/dev/repos,
# build akagent from the attached akagent-cli, and expose notes-task/syncdots.
# Idempotent. Refuses to replace a duplicate clone that is dirty, off main or has
# commits not on origin. Run bin/cloud-preflight.sh afterwards to verify. At the end of a session run bin/cloud-closeout.sh.
# Usage: cloud-link-repos.sh [attach-root]   (default: detected; see cloud-lib.sh)
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/cloud-lib.sh"
attach_root=$(cloud_attach_root "${1:-}")
dev_repos=${DEV_REPOS:-"$HOME/dev/repos"}
bin_dir="$HOME/.local/bin"
mkdir -p "$dev_repos" "$bin_dir"

for dir in "$attach_root"/*/; do
  [[ -e "$dir/.git" ]] || continue
  name=$(basename "$dir")
  src="$attach_root/$name"
  target="$dev_repos/$name"
  if [[ -L "$target" ]]; then
    [[ "$(readlink -f "$target")" == "$(readlink -f "$src")" ]] || { echo "$name: link points elsewhere; leaving it" >&2; exit 1; }
    continue
  fi
  if [[ -e "$target" ]]; then
    if [[ -n "$(git -C "$target" status --porcelain)" ]] ||
      [[ -n "$(git -C "$target" log --branches --not --remotes --oneline | head -1)" ]]; then
      echo "$name: duplicate clone has local state; leaving it" >&2; exit 1
    fi
    rm -rf "$target"
  fi
  ln -s "$src" "$target"
  echo "linked $target -> $src"
done

if [[ -d "$attach_root/akagent-cli" ]] && ! command -v akagent >/dev/null 2>&1; then
  cloud_ensure_go || echo "no working go; akagent not built" >&2
  (cd "$attach_root/akagent-cli" && go build -o "$bin_dir/akagent" ./cmd/akagent)
  ln -sfn akagent "$bin_dir/aka"
  echo "built $bin_dir/akagent"
fi

if [[ -d "$attach_root/dots" ]]; then
  ln -sfn "$attach_root/dots/bin/dots-sync.sh" "$bin_dir/syncdots"
  ln -sfn "$attach_root/dots/bin/notes-task.py" "$bin_dir/notes-task"
fi

case ":$PATH:" in *":$bin_dir:"*) ;; *) echo "add $bin_dir to PATH" ;; esac
