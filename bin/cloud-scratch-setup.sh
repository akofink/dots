#!/usr/bin/env bash
# Scratch-mode cloud setup for sessions whose HOME is read-only (OpenAI cloud's agent phase: only /workspace
# and /tmp are writable). Instead of linking repos into ~/dev/repos and editing ~/.gitconfig, ~/.bashrc and
# ~/.local/bin, it builds everything under a scratch directory (default /tmp/cloud-agent):
#   bin/notes-task, bin/akagent, bin/aka   wrappers that carry their own environment, so absolute paths work
#                                          without sourcing anything
#   env.sh                                 exports for an interactive shell: source it once per shell
# Environment it sets for those tools: DEV_REPOS/NOTES_REPO/DOTS_REPO point at the attached checkouts,
# NOTES_AGENT_REPO and NOTES_WORKTREE_ROOT live in scratch, XDG_STATE_HOME and the Go caches live in scratch,
# and commit signing is turned off through GIT_CONFIG_* (no config file is edited).
# syncdots is not provided: it links agent skills under HOME. Push with `git push origin HEAD:main`.
# Idempotent and best effort. Usage: cloud-scratch-setup.sh [attach-root]
set -uo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$script_dir/cloud-lib.sh"
attach_root=$(cloud_attach_root "${1:-}")
scratch=$(cloud_scratch_dir)
status=0
mkdir -p "$scratch/bin" "$scratch/state" "$scratch/worktrees" "$scratch/gocache" "$scratch/gopath" "$scratch/tmp" || exit 1

env_lines=$(cat <<ENVEOF
export DEV_REPOS='$attach_root'
export DOTS_REPO='$attach_root/dots'
export NOTES_REPO='$attach_root/notes'
export NOTES_AGENT_REPO='$scratch/notes-agent'
export NOTES_WORKTREE_ROOT='$scratch/worktrees/notes'
export XDG_STATE_HOME='$scratch/state'
export GOCACHE='$scratch/gocache'
export GOPATH='$scratch/gopath'
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=commit.gpgsign
export GIT_CONFIG_VALUE_0=false
export PATH='$scratch/bin':"\$PATH"
ENVEOF
)
printf '%s\n' "$env_lines" > "$scratch/env.sh"
# shellcheck disable=SC1091
source "$scratch/env.sh"

# Go: a real toolchain under scratch when the resolved `go` is not Go.
if [[ -d "$attach_root/akagent-cli" ]] && ! go version 2>/dev/null | grep -q '^go version go'; then
  version=${GO_VERSION:-1.25.9}
  case "$(uname -m)" in x86_64) arch=amd64 ;; aarch64 | arm64) arch=arm64 ;; *) arch= ;; esac
  if [[ -n "$arch" ]] && curl -fsSL "https://go.dev/dl/go${version}.linux-${arch}.tar.gz" | tar -xz -C "$scratch"; then
    ln -sfn "$scratch/go/bin/go" "$scratch/bin/go"
  else
    echo "cloud-scratch-setup: could not install Go; akagent not built" >&2; status=1
  fi
fi

if [[ -d "$attach_root/akagent-cli" ]] && [[ ! -x "$scratch/bin/akagent-bin" ]] && go version >/dev/null 2>&1; then
  (cd "$attach_root/akagent-cli" && go build -o "$scratch/bin/akagent-bin" ./cmd/akagent) || { echo "cloud-scratch-setup: akagent build failed" >&2; status=1; }
fi

# Wrappers: self-contained environment, so tool calls that start a fresh shell can use absolute paths.
write_wrapper() {  # name, command...
  local name=$1; shift
  { printf '#!/usr/bin/env bash\nsource %q\nexec' "$scratch/env.sh"; printf ' %q' "$@"; printf ' "$@"\n'; } > "$scratch/bin/$name"
  chmod +x "$scratch/bin/$name"
}
[[ -f "$attach_root/dots/bin/notes-task.py" ]] && write_wrapper notes-task python3 "$attach_root/dots/bin/notes-task.py"
if [[ -x "$scratch/bin/akagent-bin" ]]; then
  write_wrapper akagent "$scratch/bin/akagent-bin"
  write_wrapper aka "$scratch/bin/akagent-bin"
fi

# ShellCheck for the dots git hooks, outside HOME.
if ! command -v shellcheck >/dev/null 2>&1 && command -v pip >/dev/null 2>&1; then
  pip install -q --target "$scratch/shellcheck-py" shellcheck-py >/dev/null 2>&1 &&
    [[ -x "$scratch/shellcheck-py/bin/shellcheck" ]] && write_wrapper shellcheck "$scratch/shellcheck-py/bin/shellcheck" ||
    echo "cloud-scratch-setup: could not install shellcheck; dots pushes will be refused until it exists" >&2
fi

echo "cloud-scratch-setup: scratch mode ready in $scratch (call $scratch/bin/<tool> or: source $scratch/env.sh)"
exit "$status"
