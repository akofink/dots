#!/usr/bin/env bash
# Read-only cloud-session preflight: reports the repo path map, tools present and
# what must be linked before notes-task/akagent/syncdots can be used. Changes nothing.
# Usage: cloud-preflight.sh [attach-root]   (default attach root: /home/user)
set -uo pipefail

attach_root=${1:-/home/user}
dev_repos=${DEV_REPOS:-"$HOME/dev/repos"}
status=0

printf 'HOME=%s user=%s\n' "$HOME" "$(id -un)"
printf '\n## Attached repos (%s)\n' "$attach_root"
attached=()
for dir in "$attach_root"/*/; do
  [[ -e "$dir/.git" ]] || continue
  name=$(basename "$dir")
  attached+=("$name")
  printf '%s: branch=%s origin=%s dirty=%s\n' "$name" \
    "$(git -C "$dir" branch --show-current 2>/dev/null)" \
    "$(git -C "$dir" remote get-url origin 2>/dev/null)" \
    "$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
done
[[ ${#attached[@]} -gt 0 ]] || printf '(none)\n'

printf '\n## Path map (%s)\n' "$dev_repos"
for name in "${attached[@]}"; do
  target="$dev_repos/$name"
  if [[ -L "$target" ]]; then
    if [[ "$(readlink -f "$target")" == "$(readlink -f "$attach_root/$name")" ]]; then
      printf '%s: ok (link to attached repo)\n' "$name"
    else
      printf '%s: WRONG link -> %s\n' "$name" "$(readlink -f "$target")"; status=1
    fi
  elif [[ -e "$target" ]]; then
    printf '%s: DUPLICATE clone at %s (attached repo is ignored by tools)\n' "$name" "$target"; status=1
  else
    printf '%s: missing (would link %s -> %s)\n' "$name" "$target" "$attach_root/$name"; status=1
  fi
done

printf '\n## Tools\n'
for tool in git rg xh python3 go tmux hc akagent agent-workflow notes-task syncdots; do
  if command -v "$tool" >/dev/null 2>&1; then printf '%s: present\n' "$tool"
  else printf '%s: absent\n' "$tool"; fi
done

printf '\n## Context\n'
owners=$(for name in "${attached[@]}"; do git -C "$attach_root/$name" remote get-url origin 2>/dev/null; done |
  sed -E 's#.*[:/]([^/]+)/[^/]+(\.git)?$#\1#' | sort -u | paste -sd, -)
printf 'remote owners: %s (work vs personal is the operator'"'"'s call; not inferred)\n' "${owners:-none}"
printf 'push grants: not probed (read-only); a push needs a per-session grant per repo\n'

exit "$status"
