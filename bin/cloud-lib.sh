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
