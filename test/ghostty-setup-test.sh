#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"

cat > "$tmp/bin/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${MOCK_UNAME:-Darwin}"
EOF
cat > "$tmp/bin/brew" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$BREW_LOG"
EOF
chmod +x "$tmp/bin/uname" "$tmp/bin/brew"

run_setup() {
  PATH="$tmp/bin:/usr/bin:/bin" \
    HOME="$tmp/home" \
    DOTS_REPO="$repo_root" \
    UTIL_SETUP_COMPLETE=1 \
    BREW_LOG="$tmp/brew.log" \
    MOCK_UNAME="${1:?}" \
    bash -c '
      eval_template() { mkdir -p "$(dirname "$2")"; cp "$1" "$2"; }
      export -f eval_template
      source "$DOTS_REPO/setup/ghostty.sh"
    '
}

# Non-macOS platforms must exit before touching Ghostty paths or installing.
for platform in Linux FreeBSD; do
  rm -f "$tmp/brew.log"
  run_setup "$platform"
  [[ ! -e "$tmp/home/.config/ghostty" ]]
  [[ ! -e "$tmp/brew.log" ]]
done
# WSL reports Linux from uname; verify its environment marker changes nothing.
rm -f "$tmp/brew.log"
PATH="$tmp/bin:/usr/bin:/bin" HOME="$tmp/home" DOTS_REPO="$repo_root" \
  UTIL_SETUP_COMPLETE=1 BREW_LOG="$tmp/brew.log" MOCK_UNAME=Linux WSL_DISTRO_NAME=Ubuntu bash -c '
    eval_template() { touch "$2"; }
    export -f eval_template
    source "$DOTS_REPO/setup/ghostty.sh"
  '
[[ ! -e "$tmp/home/.config/ghostty" ]]
[[ ! -e "$tmp/brew.log" ]]

# macOS installs only when the executable is absent and applies the template.
rm -rf "$tmp/home/.config" "$tmp/brew.log"
run_setup Darwin
[[ "$(<"$tmp/brew.log")" == "install --cask ghostty" ]]
cmp -s "$repo_root/templates/ghostty/config" "$tmp/home/.config/ghostty/config"

# An existing Ghostty must not be installed again; repeated application is safe.
mkdir -p "$tmp/installed-bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$tmp/installed-bin/ghostty"
chmod +x "$tmp/installed-bin/ghostty"
PATH="$tmp/installed-bin:$tmp/bin:/usr/bin:/bin" HOME="$tmp/home" DOTS_REPO="$repo_root" \
  UTIL_SETUP_COMPLETE=1 BREW_LOG="$tmp/brew.log" MOCK_UNAME=Darwin bash -c '
    eval_template() { mkdir -p "$(dirname "$2")"; cp "$1" "$2"; }
    export -f eval_template
    source "$DOTS_REPO/setup/ghostty.sh"
  '
[[ "$(<"$tmp/brew.log")" == "install --cask ghostty" ]]

printf '%s\n' 'ghostty setup platform tests passed'
