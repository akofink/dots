#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

for command in brew pi claude codex atlas; do
  cat > "$tmp/bin/$command" <<'STUB'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "$CALL_LOG"
if [[ "${FAIL_COMMAND:-}" == "$(basename "$0")" ]]; then
  exit 17
fi
STUB
  chmod +x "$tmp/bin/$command"
done

export CALL_LOG="$tmp/calls"
export PATH="$tmp/bin:$PATH"

MACHINE_CLASS=personal bash "$repo_root/bin/akupdate.sh" > "$tmp/personal.out"
grep -q '^brew update$' "$CALL_LOG"
grep -q '^brew upgrade$' "$CALL_LOG"
grep -q '^pi update --all$' "$CALL_LOG"
grep -q '^claude update$' "$CALL_LOG"
grep -q '^codex update$' "$CALL_LOG"
! grep -q '^atlas ' "$CALL_LOG"
grep -q 'Pi and extensions: OK' "$tmp/personal.out"

: > "$CALL_LOG"
if MACHINE_CLASS=work FAIL_COMMAND=pi bash "$repo_root/bin/akupdate.sh" > "$tmp/work.out"; then
  echo 'Expected failed update to return nonzero' >&2
  exit 1
fi
grep -q '^atlas update$' "$CALL_LOG"
grep -q '^atlas plugin update --all$' "$CALL_LOG"
grep -q 'Pi and extensions: FAILED (exit 17)' "$tmp/work.out"
grep -q 'Atlas CLI: OK' "$tmp/work.out"
grep -q 'Atlas plugins: OK' "$tmp/work.out"

echo 'akupdate tests passed'
