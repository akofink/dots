#!/usr/bin/env bash
# Read-only cloud-session preflight: reports the repo path map, tools present and
# what must be linked before notes-task/akagent/syncdots can be used. Changes nothing.
# Usage: cloud-preflight.sh [attach-root]   (default: detected; see cloud-lib.sh)
set -uo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/cloud-lib.sh"
attach_root=$(cloud_attach_root "${1:-}")
dev_repos=${DEV_REPOS:-"$HOME/dev/repos"}
status=0

printf 'HOME=%s user=%s\n' "$HOME" "$(id -un)"

printf '\n## Environment\n'
# Providers are detected by cloud-lib.sh (claude, codex). The variable names below (names only,
# never values) are what to record from a first session on a new provider.
provider=$(cloud_provider)
if [[ "$provider" == unknown ]]; then
  printf 'cloud: no known marker (unrecognized provider, or a local machine)\n'
else
  printf 'cloud: yes (%s cloud, environment type %s)\n' "$provider" "${CLAUDE_CODE_REMOTE_ENVIRONMENT_TYPE:-${CODEX_PERMISSION_PROFILE:-unknown}}"
fi
printf 'attach root: %s\n' "$attach_root"
printf 'cwd=%s uname=%s\n' "$PWD" "$(uname -sr)"
printf 'candidate env names: %s\n' "$(env | cut -d= -f1 | grep -Ei 'codex|openai|ccr|remote|cloud|sandbox|proxy|workspace' | sort | tr '\n' ' ')"
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
printf 'commit.gpgsign=%s (cloud sessions need false; cloud-session-setup.sh sets it)\n' "$(git config --global commit.gpgsign 2>/dev/null || echo unset)"
case ":$PATH:" in *":$HOME/.local/bin:"*) printf '~/.local/bin on PATH: yes\n' ;; *) printf '~/.local/bin on PATH: no\n' ;; esac
owners=$(for name in "${attached[@]}"; do git -C "$attach_root/$name" remote get-url origin 2>/dev/null; done |
  sed -E 's#.*[:/]([^/]+)/[^/]+(\.git)?$#\1#' | sort -u | paste -sd, -)
printf 'remote owners: %s (work vs personal is the operator'"'"'s call; not inferred)\n' "${owners:-none}"
printf 'push grants: not probed (read-only); a push needs a per-session grant per repo\n'
if [[ "$status" -ne 0 ]]; then
  printf 'next: bash %s %s   (links the repos; then rerun this preflight)\n' "$(dirname "${BASH_SOURCE[0]}")/cloud-session-setup.sh" "$attach_root"
fi

exit "$status"
