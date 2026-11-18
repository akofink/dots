#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat > "$tmp/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf 'download\n' >> "$CALLS"
while [[ $# -gt 0 ]]; do
  if [[ "$1" == -o ]]; then
    shift
    printf '#!/usr/bin/env bash\nprintf "installer\\n" >> "$CALLS"\nmkdir -p "$HOME/.opencode/bin"\ntouch "$HOME/.opencode/bin/opencode"\nchmod +x "$HOME/.opencode/bin/opencode"\n' > "$1"
    exit 0
  fi
  shift
done
exit 1
STUB
chmod +x "$tmp/bin/curl"
for class in work personal; do
  mkdir -p "$tmp/$class"
  HOME="$tmp/$class" CALLS="$tmp/$class/calls" PATH="$tmp/bin:$PATH" \
    MACHINE_CLASS="$class" UTIL_SETUP_COMPLETE=1 \
    bash -c 'set -e; source "$1/setup/opencode.sh"; [[ "$OPENCODE_SETUP_COMPLETE" == 1 ]]' _ "$repo"
  if [[ "$class" == work ]]; then
    [[ ! -e "$tmp/$class/calls" && ! -e "$tmp/$class/.opencode/bin/opencode" ]]
  else
    [[ $(<"$tmp/$class/calls") == $'download\ninstaller' ]]
    [[ -x "$tmp/$class/.opencode/bin/opencode" ]]
  fi
done
echo 'opencode-install-test: ok'
