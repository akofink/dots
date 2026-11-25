#!/usr/bin/env bash
# Shared helpers for the cloud-* scripts. Source this file; it defines functions only.
#
# cloud_provider: claude | codex | unknown. CLOUD_PROVIDER overrides (used by tests).
#   claude: CLAUDE_CODE_REMOTE=true, CCR_AGENT_PROXY_ENABLED or /root/.ccr
#   codex:  CODEX_ENVIRONMENT_ID or CODEX_CAAS_SESSION_ID (observed in an OpenAI cloud session, 2026-11-25)
# cloud_attach_root [arg]: the directory holding the attached checkouts. An explicit argument wins,
#   then CLOUD_ATTACH_ROOT, then the first of /home/user (Claude Code cloud), /workspace (OpenAI cloud)
#   or the current directory that contains a git checkout.

cloud_provider() {
  if [[ -n "${CLOUD_PROVIDER:-}" ]]; then printf '%s\n' "$CLOUD_PROVIDER"; return; fi
  if [[ "${CLAUDE_CODE_REMOTE:-}" == true || -n "${CCR_AGENT_PROXY_ENABLED:-}" || -d /root/.ccr ]]; then
    printf 'claude\n'
  elif [[ -n "${CODEX_ENVIRONMENT_ID:-}" || -n "${CODEX_CAAS_SESSION_ID:-}" ]]; then
    printf 'codex\n'
  else
    printf 'unknown\n'
  fi
}

cloud_attach_root() {
  local candidate dir
  if [[ -n "${1:-}" ]]; then printf '%s\n' "$1"; return; fi
  if [[ -n "${CLOUD_ATTACH_ROOT:-}" ]]; then printf '%s\n' "$CLOUD_ATTACH_ROOT"; return; fi
  for candidate in /home/user /workspace "$PWD"; do
    for dir in "$candidate"/*/; do
      if [[ -e "$dir/.git" ]]; then printf '%s\n' "$candidate"; return; fi
    done
  done
  printf '/home/user\n'
}

# cloud_update_repos <attach-root>: fast-forward each clean attached checkout to origin/main when its
# current commit is an ancestor of origin/main (a cached container can hold stale checkouts, as an OpenAI
# cloud session did). Never touches a dirty tree, a checkout with commits not on origin/main, or a diverged
# branch. Prints one line per checkout that moved or could not be updated.
cloud_update_repos() {
  local root=$1 dir name
  for dir in "$root"/*/; do
    [[ -e "$dir/.git" ]] || continue
    name=$(basename "$dir")
    [[ -z "$(git -C "$dir" status --porcelain 2>/dev/null)" ]] || { echo "$name: dirty; not updated"; continue; }
    git -C "$dir" fetch -q origin main 2>/dev/null || { echo "$name: fetch failed; not updated"; continue; }
    if git -C "$dir" merge-base --is-ancestor HEAD origin/main && ! git -C "$dir" merge-base --is-ancestor origin/main HEAD; then
      git -C "$dir" merge -q --ff-only origin/main && echo "$name: fast-forwarded to $(git -C "$dir" rev-parse --short HEAD)"
    elif ! git -C "$dir" merge-base --is-ancestor HEAD origin/main; then
      echo "$name: has commits not on origin/main; not updated"
    fi
  done
}
