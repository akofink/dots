#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
closeout="$repo_root/bin/cloud-closeout.sh"

git init -q --bare "$tmp/origin.git" -b main
git clone -q "$tmp/origin.git" "$tmp/seed" 2>/dev/null
(cd "$tmp/seed" && git checkout -q -b main && printf a > a && git add a && git commit -qm a && git push -q origin main)
mkdir "$tmp/root"
git clone -q "$tmp/origin.git" "$tmp/root/repo"

cd "$tmp/root/repo"
git checkout -q -b claude/slug
printf b > b && git add b && git commit -qm b
# Branch has a commit that is not in origin/main: must report and change nothing.
if "$closeout" "$tmp/root" >/dev/null; then echo 'unmerged branch passed' >&2; exit 1; fi
[[ "$(git branch --show-current)" == claude/slug ]]

# Deliver to main, then closeout purges the merged branch and lands on main.
git push -q origin HEAD:main
"$closeout" --check "$tmp/root" >/dev/null && { echo 'check passed off main' >&2; exit 1; }
"$closeout" "$tmp/root" | grep -q 'deleted merged branch claude/slug'
[[ "$(git branch --show-current)" == main ]]
[[ -z "$(git branch --list claude/slug)" ]]
[[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]]
"$closeout" --check "$tmp/root" | grep -q 'ok (main at origin/main)'

# Dirty tree and unpushed main are reported and left alone.
printf c >> a
if "$closeout" "$tmp/root" >/dev/null; then echo 'dirty tree passed' >&2; exit 1; fi
git checkout -q -- a
printf d > d && git add d && git commit -qm d
if "$closeout" "$tmp/root" >/dev/null; then echo 'unpushed main passed' >&2; exit 1; fi

# Non-Claude providers retain the harness branch and never switch or delete it.
git reset -q --hard origin/main
git checkout -q -b work
CLOUD_PROVIDER=codex "$closeout" "$tmp/root" | grep -q 'harness branch work retained'
[[ "$(git branch --show-current)" == work ]]
[[ -n "$(git branch --list work)" ]]
printf 'x' > x && git add x && git commit -qm x
if CLOUD_PROVIDER=codex "$closeout" "$tmp/root" >/dev/null; then echo 'unmerged work branch passed' >&2; exit 1; fi

# Attach root detection: an explicit root wins; CLOUD_ATTACH_ROOT is next.
source "$repo_root/bin/cloud-lib.sh"
[[ "$(cloud_attach_root /x)" == /x ]]
[[ "$(CLOUD_ATTACH_ROOT=/y cloud_attach_root)" == /y ]]
[[ "$(CODEX_ENVIRONMENT_ID=e CLAUDE_CODE_REMOTE= CCR_AGENT_PROXY_ENABLED= cloud_provider)" != unknown ]]

printf 'cloud-closeout-test: ok\n'
