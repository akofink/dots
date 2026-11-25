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
scratch=$(cloud_scratch_dir)
if cloud_home_writable; then
  printf 'home writable: yes\n'
  scratch_mode=0
else
  printf 'home writable: NO (read-only HOME; tools run in scratch mode from %s)\n' "$scratch"
  scratch_mode=1
  [[ -d "$scratch/bin" ]] && PATH="$scratch/bin:$PATH"
fi
printf 'cwd=%s uname=%s\n' "$PWD" "$(uname -sr)"
printf 'candidate env names: %s\n' "$(env | cut -d= -f1 | grep -Ei 'codex|openai|ccr|remote|cloud|sandbox|proxy|workspace' | sort | tr '\n' ' ')"
printf '\n## Attached repos (%s)\n' "$attach_root"
attached=()
for dir in "$attach_root"/*/; do
  [[ -e "$dir/.git" ]] || continue
  name=$(basename "$dir")
  attached+=("$name")
  git -C "$dir" fetch -q origin main 2>/dev/null
  behind=$(git -C "$dir" rev-list --count HEAD..origin/main 2>/dev/null || echo '?')
  printf '%s: branch=%s origin=%s dirty=%s behind_origin_main=%s\n' "$name" \
    "$(git -C "$dir" branch --show-current 2>/dev/null)" \
    "$(git -C "$dir" remote get-url origin 2>/dev/null)" \
    "$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')" "$behind"
  [[ "$behind" == 0 || "$behind" == '?' ]] || status=1
done
[[ ${#attached[@]} -gt 0 ]] || printf '(none)\n'

if [[ "$scratch_mode" -eq 1 ]]; then
  printf '\n## Scratch mode (%s)\n' "$scratch"
  if [[ -f "$scratch/env.sh" ]]; then
    printf 'scratch env: ready (source %s/env.sh, or call %s/bin/<tool>)\n' "$scratch" "$scratch"
  else
    printf 'scratch env: missing\n'; status=1
  fi
  attached=()
fi
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
  if [[ "$tool" == go ]] && command -v go >/dev/null 2>&1; then
    if go version 2>/dev/null | grep -q '^go version go'; then printf 'go: present (%s)\n' "$(go version | cut -d' ' -f3)"
    else printf 'go: UNUSABLE (%s resolves but `go version` fails; setup installs a real Go)\n' "$(command -v go)"; status=1; fi
  elif command -v "$tool" >/dev/null 2>&1; then printf '%s: present\n' "$tool"
  else printf '%s: absent\n' "$tool"; fi
done

printf '\n## Context\n'
if [[ "$scratch_mode" -eq 1 ]]; then
  printf 'commit.gpgsign: set to false by the scratch env (GIT_CONFIG_*); PATH: use %s/bin/<tool>\n' "$scratch"
else
  printf 'commit.gpgsign=%s (cloud sessions need false; cloud-session-setup.sh sets it)\n' "$(git config --global commit.gpgsign 2>/dev/null || echo unset)"
  case ":$PATH:" in *":$HOME/.local/bin:"*) printf '%s on PATH: yes\n' "$HOME/.local/bin" ;; *) printf '%s on PATH: no\n' "$HOME/.local/bin" ;; esac
  owners=$(for name in "${attached[@]}"; do git -C "$attach_root/$name" remote get-url origin 2>/dev/null; done |
    sed -E 's#.*[:/]([^/]+)/[^/]+(\.git)?$#\1#' | sort -u | paste -sd, -)
fi
printf 'remote owners: %s (work vs personal is the operator'"'"'s call; not inferred)\n' "${owners:-none}"
printf 'push grants: not probed (read-only); a push needs a per-session grant per repo\n'
if [[ "$status" -ne 0 ]]; then
  printf 'next: bash %s %s   (links the repos; then rerun this preflight)\n' "$(dirname "${BASH_SOURCE[0]}")/cloud-session-setup.sh" "$attach_root"
fi

exit "$status"
