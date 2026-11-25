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

# cloud_ensure_go: make `go version` work. A cloud image can carry a different tool named `go` (an OpenAI
# cloud session had /usr/bin/go answering "Go: Unknown option: build"), so `command -v go` proves nothing.
# When `go version` does not report a Go toolchain, install GO_VERSION (default 1.25.9, as dots setup/go.sh)
# from go.dev into ~/.local/go and link go and gofmt into ~/.local/bin, which is put first on PATH.
cloud_ensure_go() {
  local version=${GO_VERSION:-1.25.9} arch url
  if go version 2>/dev/null | grep -q '^go version go'; then return 0; fi
  [[ "$(uname -s)" == Linux ]] || { echo "cloud_ensure_go: no working go and automatic install supports Linux only" >&2; return 1; }
  case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *) echo "cloud_ensure_go: unsupported architecture $(uname -m)" >&2; return 1 ;;
  esac
  url="https://go.dev/dl/go${version}.linux-${arch}.tar.gz"
  mkdir -p "$HOME/.local/bin"
  rm -rf "$HOME/.local/go"
  curl -fsSL "$url" | tar -xz -C "$HOME/.local" || { echo "cloud_ensure_go: could not install Go from $url" >&2; return 1; }
  ln -sfn "$HOME/.local/go/bin/go" "$HOME/.local/bin/go"
  ln -sfn "$HOME/.local/go/bin/gofmt" "$HOME/.local/bin/gofmt"
  export PATH="$HOME/.local/bin:$PATH"
  go version 2>/dev/null | grep -q '^go version go'
}

# cloud_home_writable: true when HOME accepts new files under ~/.local/bin (OpenAI cloud's agent phase has a
# read-only HOME while /workspace and /tmp are writable).
cloud_home_writable() {
  mkdir -p "$HOME/.local/bin" 2>/dev/null && [[ -w "$HOME/.local/bin" ]]
}

# cloud_scratch_dir: where scratch mode keeps its wrappers, state and clones (CLOUD_SCRATCH overrides).
cloud_scratch_dir() {
  printf '%s\n' "${CLOUD_SCRATCH:-${TMPDIR:-/tmp}/cloud-agent}"
}
