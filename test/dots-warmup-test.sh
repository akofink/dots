#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Fingerprints are content-stable and include the declared module source.
mkdir -p "$tmp/dots/setup" "$tmp/dots/templates" "$tmp/notes/agents" "$tmp/notes/skills"
printf 'module\n' > "$tmp/dots/setup/llm.sh"
printf 'template\n' > "$tmp/dots/templates/config"
printf 'guide\n' > "$tmp/notes/agents/guide.md"
a=$(python3 "$repo/bin/dots-setup-state.py" llm "$tmp/dots" "$tmp/notes")
b=$(python3 "$repo/bin/dots-setup-state.py" llm "$tmp/dots" "$tmp/notes")
[[ "$a" == "$b" ]]
printf 'changed\n' >> "$tmp/notes/agents/guide.md"
c=$(python3 "$repo/bin/dots-setup-state.py" llm "$tmp/dots" "$tmp/notes")
[[ "$c" != "$a" ]]

# --changed selection and --dry-run do not touch state or run modules.
state="$tmp/dots-setup"
mkdir -p "$state"
for module in http aws vim tmux zsh llm opencode rbenv go tmuxinator glow ghostty akagent; do
  printf '%s\n' "$(python3 "$repo/bin/dots-setup-state.py" "$module" "$repo" "$tmp/notes")" > "$state/$module"
done
before=$(shasum -a 256 "$state"/* | shasum -a 256)
DOTS_REPO="$repo" NOTES_REPO="$tmp/notes" XDG_STATE_HOME="$tmp" bash "$repo/setup.sh" --changed --dry-run > "$tmp/changed.out"
grep -q 'No setup modules need to run' "$tmp/changed.out"
printf 'new guide input\\n' > "$tmp/notes/agents/new.md"
DOTS_REPO="$repo" NOTES_REPO="$tmp/notes" XDG_STATE_HOME="$tmp" bash "$repo/setup.sh" --changed --dry-run > "$tmp/changed.out"
grep -q 'Would run setup modules: llm' "$tmp/changed.out"
DOTS_REPO="$repo" NOTES_REPO="$tmp/notes" XDG_STATE_HOME="$tmp" bash "$repo/setup.sh" --dry-run > "$tmp/full.out"
grep -q 'http aws vim' "$tmp/full.out"
after=$(shasum -a 256 "$state"/* | shasum -a 256)
[[ "$before" == "$after" ]]
mkdir -p "$tmp/locked-state/dots-sync/lock"
if DOTS_REPO="$repo" NOTES_REPO="$tmp/notes" XDG_STATE_HOME="$tmp/locked-state" bash "$repo/setup.sh" --changed --dry-run > "$tmp/locked.out" 2>&1; then
  echo 'setup overlapped an active sync lock' >&2; exit 1
fi
DOTS_WARMUP_LOCKED=1 DOTS_REPO="$repo" NOTES_REPO="$tmp/notes" XDG_STATE_HOME="$tmp/locked-state" \
  bash "$repo/setup.sh" --changed --dry-run > "$tmp/locked-child.out"
grep -q 'Would run setup modules:' "$tmp/locked-child.out"

# A successful fake module refreshes its stamp; a failed run preserves it.
fake_repo="$tmp/fake-repo"
mkdir -p "$fake_repo/setup" "$fake_repo/bin"
cp "$repo/bin/dots-setup-state.py" "$fake_repo/bin/"
printf 'return 0\n' > "$fake_repo/setup/llm.sh"
REPOS_SETUP_COMPLETE=1 DOTS_REPO="$fake_repo" NOTES_REPO="$tmp/notes" XDG_STATE_HOME="$tmp/success-state" HOME="$tmp/home" \
  bash "$repo/setup.sh" --only llm > "$tmp/module.out"
old_stamp=$(<"$tmp/success-state/dots-setup/llm")
printf 'return 7\n' > "$fake_repo/setup/llm.sh"
if REPOS_SETUP_COMPLETE=1 DOTS_REPO="$fake_repo" NOTES_REPO="$tmp/notes" XDG_STATE_HOME="$tmp/success-state" HOME="$tmp/home" \
  bash "$repo/setup.sh" --only llm > "$tmp/module-fail.out" 2>&1; then
  echo 'expected fake module failure' >&2; exit 1
fi
[[ $(<"$tmp/success-state/dots-setup/llm") == "$old_stamp" ]]
printf 'return 0\n' > "$fake_repo/setup/llm.sh"
REPOS_SETUP_COMPLETE=1 DOTS_REPO="$fake_repo" NOTES_REPO="$tmp/notes" XDG_STATE_HOME="$tmp/pending-state" HOME="$tmp/home" MACHINE_CLASS=work \
  bash "$repo/setup.sh" --changed > "$tmp/pending.out"
[[ -s "$tmp/pending-state/dots-setup/pending" ]]
[[ $(<"$tmp/pending-state/dots-setup/pending") == 'http aws vim tmux zsh opencode rbenv go tmuxinator glow ghostty akagent' ]]
mkdir -p "$tmp/pending-state/dots-warmup" "$tmp/actions"
printf 'warmup.log\n' > "$tmp/pending-state/dots-warmup/failure"
cat > "$tmp/actions/source.md" <<'MD'
## Machine-wide actions (by host)
### Operator actions
#### akmac
- [ ] akmac action
#### akwin
- [ ] akwin action
#### any host
- [ ] shared action
MD
PERSONAL_ACTION_LIST_FILE="$tmp/actions/source.md" PERSONAL_ACTION_HOST=akmac \
  XDG_STATE_HOME="$tmp/pending-state" HOME="$tmp/home" bash "$repo/bin/dots-warmup-report.sh" > "$tmp/report.out" 2> "$tmp/report.err"
grep -q '^Machine-wide personal actions:$' "$tmp/report.out"
grep -q 'akmac action' "$tmp/report.out"
grep -q 'shared action' "$tmp/report.out"
! grep -q 'akwin action' "$tmp/report.out"
grep -q '^Dots setup pending interactive modules:' "$tmp/report.out"
grep -q '^Dots background warmup failed: warmup.log$' "$tmp/report.err"
PERSONAL_ACTION_LIST_FILE="$tmp/actions/source.md" PERSONAL_ACTION_HOST=akmac \
  XDG_STATE_HOME="$tmp/pending-state" HOME="$tmp/home" bash "$repo/bin/dots-warmup-report.sh" > "$tmp/report-again.out" 2> "$tmp/report-again.err"
grep -q 'akmac action' "$tmp/report-again.out"
grep -q 'shared action' "$tmp/report-again.out"
[[ ! -s "$tmp/report-again.err" ]]

# Isolated cadence tests use only fake setup/updater commands and an injected clock.
mkdir -p "$tmp/bin"
cat > "$tmp/bin/setup" <<'SH'
#!/usr/bin/env bash
[[ "$1" == --changed ]]
SH
cat > "$tmp/bin/update" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$CALL_LOG"
[[ "${FAIL_MODE:-}" != "$1" ]]
SH
chmod +x "$tmp/bin/setup" "$tmp/bin/update"
export CALL_LOG="$tmp/calls"
run_warmup() {
  DOTS_WARMUP_SETUP="$tmp/bin/setup" DOTS_WARMUP_UPDATER="$tmp/bin/update" \
    DOTS_WARMUP_NOW="$1" XDG_STATE_HOME="$tmp/warm-state" HOME="$tmp/home" \
    MACHINE_CLASS="$2" bash "$repo/bin/dots-warmup.sh"
}
mkdir -p "$tmp/home"
run_warmup 100000 personal
[[ $(wc -l < "$CALL_LOG" | tr -d ' ') == 2 ]]
run_warmup 100001 personal
[[ $(wc -l < "$CALL_LOG" | tr -d ' ') == 2 ]]
run_warmup 186401 personal
[[ $(wc -l < "$CALL_LOG" | tr -d ' ') == 3 ]]
run_warmup 704801 personal
[[ $(wc -l < "$CALL_LOG" | tr -d ' ') == 5 ]]
run_warmup 704802 work
[[ $(wc -l < "$CALL_LOG" | tr -d ' ') == 5 ]]
# Failure does not advance the daily timestamp.
rm -f "$tmp/warm-state/dots-warmup/daily"
if FAIL_MODE=--warmup-daily DOTS_WARMUP_SETUP="$tmp/bin/setup" DOTS_WARMUP_UPDATER="$tmp/bin/update" \
  DOTS_WARMUP_NOW=800000 XDG_STATE_HOME="$tmp/fail-state" HOME="$tmp/home" MACHINE_CLASS=work \
  CALL_LOG="$tmp/fail-calls" bash "$repo/bin/dots-warmup.sh"; then
  echo 'expected fake updater failure' >&2; exit 1
fi
[[ ! -e "$tmp/fail-state/dots-warmup/daily" ]]
[[ -s "$tmp/fail-state/dots-warmup/failure" ]]
if FAIL_MODE=--warmup-weekly DOTS_WARMUP_SETUP="$tmp/bin/setup" DOTS_WARMUP_UPDATER="$tmp/bin/update" \
  DOTS_WARMUP_NOW=900000 XDG_STATE_HOME="$tmp/weekly-fail-state" HOME="$tmp/home" MACHINE_CLASS=personal \
  CALL_LOG="$tmp/weekly-fail-calls" bash "$repo/bin/dots-warmup.sh"; then
  echo 'expected fake weekly updater failure' >&2; exit 1
fi
[[ -e "$tmp/weekly-fail-state/dots-warmup/daily" ]]
[[ ! -e "$tmp/weekly-fail-state/dots-warmup/weekly" ]]

# Guidance marker only advances when notes agents/skills content changes.
guidance="$tmp/guidance"
mkdir -p "$guidance/agents" "$guidance/skills"
git -C "$guidance" init -q
git -C "$guidance" config user.email test@example.com
git -C "$guidance" config user.name test
printf 'one\n' > "$guidance/agents/guide.md"
git -C "$guidance" add . && git -C "$guidance" commit -qm initial
old=$(git -C "$guidance" rev-parse HEAD)
printf 'two\n' > "$guidance/agents/guide.md"
git -C "$guidance" commit -qam guidance
new=$(git -C "$guidance" rev-parse HEAD)
python3 "$repo/bin/dots-guidance-marker.py" "$guidance" "$old" "$new" "$tmp/guidance-state"
grep -q "commit=$new" "$tmp/guidance-state/guidance-changed"
printf 'unrelated\n' > "$guidance/README"
git -C "$guidance" add README && git -C "$guidance" commit -qm unrelated
unrelated=$(git -C "$guidance" rev-parse HEAD)
python3 "$repo/bin/dots-guidance-marker.py" "$guidance" "$new" "$unrelated" "$tmp/guidance-state"
[[ $(<"$tmp/guidance-state/guidance-changed") == "commit=$new" ]]
printf 'dots-warmup-test: ok\n'
