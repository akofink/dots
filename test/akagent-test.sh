#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

home="$test_root/home"
repos="$test_root/repos"
fake_bin="$test_root/bin"
mkdir -p "$home" "$repos" "$fake_bin"

cat > "$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1" == "-C" ]]; then
  shift 2
fi
case "$1" in
  clone)
    mkdir -p "$4/.git"
    ;;
  status)
    ;;
  branch)
    printf 'main\n'
    ;;
  fetch|merge)
    ;;
  *)
    printf 'unexpected fake git command: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$fake_bin/git"

cat > "$fake_bin/go" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output=''
while [[ $# -gt 0 ]]; do
  if [[ "$1" == '-o' ]]; then
    output="$2"
    shift 2
  else
    shift
  fi
done
printf 'fake akagent\n' > "$output"
EOF
chmod +x "$fake_bin/go"

run_installer() {
  HOME="$home" \
    DEV_REPOS="$repos" \
    DOTS_REPO="$repo_root" \
    ENV_SETUP_COMPLETE=1 \
    GO_SETUP_COMPLETE=1 \
    PATH="$fake_bin:$PATH" \
    bash "$repo_root/setup/akagent.sh"
}

aka="$home/.local/bin/aka"
akagent="$home/.local/bin/akagent"

run_installer
[[ -L "$aka" ]]
[[ "$(readlink "$aka")" == 'akagent' ]]
[[ -x "$aka" ]]
[[ "$(cat "$aka")" == 'fake akagent' ]]

run_installer
[[ "$(readlink "$aka")" == 'akagent' ]]

rm "$aka"
ln -s "$akagent" "$aka"
run_installer
[[ "$(readlink "$aka")" == 'akagent' ]]

rm "$aka"
printf 'user command\n' > "$aka"
if run_installer; then
  printf 'installer replaced an unrelated aka file\n' >&2
  exit 1
fi
[[ -f "$aka" ]]
[[ "$(cat "$aka")" == 'user command' ]]

printf 'akagent-test: ok\n'
