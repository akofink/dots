#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat "$ROOT_DIR/setup/env.sh" > "$ROOT_DIR/bootstrap.sh"
cat "$ROOT_DIR/setup/util.sh" >> "$ROOT_DIR/bootstrap.sh"

cat "$ROOT_DIR/setup/git.sh" >> "$ROOT_DIR/bootstrap.sh"
cat "$ROOT_DIR/setup/repos.sh" >> "$ROOT_DIR/bootstrap.sh"

echo '(cd "$DOTS_REPO" && ./setup.sh)' >> "$ROOT_DIR/bootstrap.sh"
chmod +x "$ROOT_DIR/bootstrap.sh"
