#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
command -v shellcheck >/dev/null 2>&1 || { printf 'git-hooks-test: skipped (shellcheck not installed)\n'; exit 0; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com

git init -q "$tmp/r"
cd "$tmp/r"
mkdir bin
cp -R "$repo_root/.githooks" .githooks
cp "$repo_root/bin/install-git-hooks.sh" bin/
printf 'check:\n\t@true\n' > Makefile
PATH="$tmp/nopip:$PATH" bash bin/install-git-hooks.sh "$tmp/r" >/dev/null
[[ "$(git config core.hooksPath)" == .githooks ]]

printf '#!/usr/bin/env bash\nx= echo hi\n' > bad.sh   # SC1007
git add bad.sh
if PATH="$(dirname "$(command -v shellcheck)"):/usr/bin:/bin" git commit -qm bad 2>/dev/null; then
  echo 'pre-commit accepted a script with a ShellCheck warning' >&2; exit 1
fi
printf '#!/usr/bin/env bash\necho hi\n' > bad.sh
git add bad.sh
git commit -qm good
printf 'git-hooks-test: ok\n'
