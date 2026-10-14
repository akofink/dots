#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
codex_bin=${CODEX_BIN:-codex}
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cp "$repo_root/templates/dot_codex/config.toml" "$tmpdir/config.toml"
rules=(--rules "$repo_root/templates/dot_codex/rules/dots.rules" --rules "$repo_root/templates/dot_codex/rules/work.rules")

check_decision() {
  local expected="$1"
  shift
  local result
  result=$(CODEX_HOME="$tmpdir" "$codex_bin" execpolicy check --pretty "${rules[@]}" -- "$@")
  if ! jq -e --arg expected "$expected" '.decision == $expected and (.matchedRules | length > 0)' <<<"$result" >/dev/null; then
    printf 'Expected %s for command: %q\n%s\n' "$expected" "$*" "$result" >&2
    return 1
  fi
}

check_decision allow git status --short
check_decision allow git commit -m 'routine engineering change'
check_decision allow cargo test --workspace
check_decision allow npm run test
check_decision allow akagent task check codex-work-command-permissions-20261014
check_decision allow aka task check codex-work-command-permissions-20261014
check_decision allow akupdate --help
check_decision allow syncdots --help
check_decision allow sfx-token --help
check_decision allow tmux-agent-state --help
check_decision allow wake-orchestrator --help
check_decision prompt git push origin main
check_decision prompt git reset --hard HEAD
check_decision prompt gh pr create --title change
check_decision prompt aws s3 rm s3://example.invalid
check_decision prompt curl https://example.invalid
check_decision prompt npm run deploy
check_decision prompt cargo publish
check_decision prompt go install example.invalid/tool
check_decision prompt bash -lc 'git status'
check_decision prompt python3 -c 'print(1)'

CODEX_HOME="$tmpdir" "$codex_bin" debug models >/dev/null
printf 'approval_policy = [\n' > "$tmpdir/config.toml"
if CODEX_HOME="$tmpdir" "$codex_bin" debug models >/dev/null 2>&1; then
  echo 'Codex accepted malformed config.toml' >&2
  exit 1
fi

printf 'codex-rules-test: native parser decisions passed\n'
