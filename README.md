# dots

Dotfiles plus installers. Run the top-level `./setup.sh` to install the curated defaults, or run any
module script individually.

## Modules

- vim
- tmux
- zsh
- llm
- opencode
- rbenv
- go
- tmuxinator
- glow

Additional helpers live under `setup/` (e.g., `git.sh`, `ssh.sh`, `nvim.sh`) and can be run directly.

Machine-role behavior is driven by shared environment detection in `setup/env.sh`. The
`MACHINE_CLASS` variable identifies the role of the current machine and defaults to `work`
on Jamf-managed hosts (`HAS_JAMF=1`) and `personal` everywhere else. Override it before
running setup to force a specific profile on a machine where auto-detection would be wrong:

```sh
MACHINE_CLASS=personal ./setup.sh
```

Current valid values are `work` and `personal`. The variable is the single place to gate
role-dependent behaviour; do not add new logic that branches on `HAS_JAMF` directly.

## Set up on any machine

Requires `bash`, `curl`, and `git` on the target system.

#### Bootstrap script

```sh
curl -O https://raw.githubusercontent.com/akofink/dots/main/bootstrap.sh && source bootstrap.sh
```

##### Regenerating the bootstrap script

```sh
./create_bootstrap.sh
```

#### From the cloned repo

##### Set up all modules

```sh
./setup.sh
```

##### Set up just one module:

```sh
bash setup/<module>.sh
```

Standalone module scripts resolve the checked-out repo automatically, so they can be run from inside the
repo or by absolute path without requiring `DOTS_REPO` to point at `$DEV_REPOS/dots`.

If you are iterating on setup scripts in the same shell, clear the exported setup state first:

```sh
eval "$(make clean)"
```

This intentionally resets the `*_SETUP_COMPLETE` flags and related exported setup variables so a later
`bash setup/<module>.sh` run does not no-op because of state leaked from an earlier sourced setup run.

The top-level `setup.sh` orchestrates a curated subset of modules: `vim`, `tmux`, `zsh`, `llm`,
`opencode`, `rbenv`, `go`, `tmuxinator`, and `glow`. Feel free to tailor that list or run any other module
script directly.

#### LLM CLI tools

`bash setup/llm.sh` installs the common LLM CLI tools configured by this repo using their official installers:

- Claude Code from `https://claude.ai/install.sh`
- Codex from `https://chatgpt.com/codex/install.sh` with `CODEX_NON_INTERACTIVE=1`
- Pi Coding Agent from `https://pi.dev/install.sh`
- opencode via `setup/opencode.sh`

Rovo/RovoDev is configuration-only; setup does not auto-install it.

#### opencode module

`bash setup/opencode.sh` installs opencode using the official installer from `https://opencode.ai/install`.
The installer places the binary in `~/.opencode/bin`; the managed shell templates already add that
directory to `PATH`, so the setup script runs the installer with `--no-modify-path`.

#### go module

`bash setup/go.sh` installs Go through `goenv` at `~/.goenv`, installs the latest stable Go version,
sets it globally, and ensures `~/go/bin` is available on `PATH` for binaries installed with `go install`.

#### glow module

`bash setup/glow.sh` installs glow from the local source checkout at `~/dev/repos/glow`.
It clones `https://github.com/charmbracelet/glow.git` when missing, fast-forwards the checkout,
builds with `go install`, and installs the resulting binary at `/usr/local/bin/glow`.
The managed solarized config is rendered to `~/Library/Preferences/glow` on macOS and
`${XDG_CONFIG_HOME:-~/.config}/glow` elsewhere.

#### Ubuntu / WSL2 notes

WSL2 system-level config is included as examples only:

- `templates/wsl/wsl.conf`
- `templates/windows-home/.wslconfig`

Those files usually need to be applied manually to `/etc/wsl.conf` and `%USERPROFILE%/.wslconfig`,
then WSL restarted.

#### LLM config module

`bash setup/llm.sh` renders tool configs and symlinks shared agent/skill files
from the private notes repo (`~/dev/repos/notes` by default). `setup/repos.sh`
clones it from `NOTES_REPO_URL` (`https://github.com/akofink/notes.git` by default)
when `NOTES_REPO` is missing:

- `~/.agents/AGENTS.md`
- `~/.claude/AGENTS.md`
- `~/.claude/CLAUDE.md`
- `~/.claude/agents/test-writer.md` when the notes repo has the target file
- `~/.config/opencode/AGENTS.md`
- `~/.config/opencode/opencode.jsonc`
- `~/.codex/config.toml`
- `~/.codex/AGENTS.md`
- `~/.codex/instructions.md`
- `~/.codex/rules/dots.rules`
- `~/.pi/AGENTS.md`
- `~/dev/AGENTS.md`

If the notes repo is not present when the LLM module runs directly, the module still renders the repo-managed Codex
config and rules, then skips the notes-backed agent and skill symlinks with a warning.

On work machines (`MACHINE_CLASS=work`) it additionally manages work-only dev and Rovo/RovoDev links:

- `~/dev/AGENTS.bbc-core.md` when the notes repo has the target file
- `~/dev/AGENTS.dss.md` when the notes repo has the target file
- `~/.rovodev/config.yml`
- `~/.rovodev/AGENTS.md`
- `~/.rovo/AGENTS.md`

The Codex rules file is a repo-managed baseline for portable allow-prefix rules. Keep machine-specific or
task-specific approvals in separate files such as `~/.codex/rules/default.rules`; `setup/llm.sh` will not
overwrite those.

The LLM tools do not expose one common config model, so shared behaviour is kept as explicit per-tool templates
instead of an abstraction layer. When changing durable defaults, check the corresponding tool config directly:

- Codex model, reasoning, approval policy, sandbox mode, and TUI defaults live in `templates/dot_codex/config.toml`.
- opencode global defaults live in `templates/dot_config/opencode/opencode.jsonc`; it currently enables LSP support.
- Shared agent instructions and skills are notes-backed symlinks where each tool supports them.
- Tool-specific auth, cache, history, project trust, missing features, and one-off permission/access grants remain local.

Shared agent instructions intentionally diverge by machine role and are canonical in the notes repo:

- personal machines link to `~/dev/repos/notes/agents/global-personal.md`, which avoids Jira, Splunk,
  Confluence, Rovo/RovoDev, and other corporate-only assumptions
- work machines (`MACHINE_CLASS=work`) link to `~/dev/repos/notes/agents/global-work.md`, which includes
  Atlassian-specific agent guidance

The `~/dev/AGENTS.md` link follows the same split: personal machines link to
`~/dev/repos/notes/dev-root-personal-AGENTS.md`, while work machines link to
`~/dev/repos/notes/dev-root-AGENTS.md`.

Skills are also symlinked from `~/dev/repos/notes/.rovodev/skills/` into the tool-specific skill directories.
Common skills are linked for all machines; work-only skills such as Jira authoring and working-state cleanup are
linked only when `MACHINE_CLASS=work`.

The rovo-managed twg (Teamwork Graph) skill bundle at `~/.local/share/rovo/current/twg/skills/` is also
symlinked into the non-rovo LLM CLIs (`~/.agents`, `~/.claude`, `~/.codex`, `~/.config/opencode`, `~/.pi`) on
`MACHINE_CLASS=work` machines only, so those tools surface the same twg skills that Rovo/RovoDev load natively.
The skill set is discovered at runtime, so it tracks rovo upgrades without a hardcoded list, and the links are
removed on personal machines or when rovo is not installed.

Rovo/RovoDev setup is work-only because those tools and instructions assume Atlassian-specific workflows.

### Template system

Templates live in `templates/` and are rendered to the home directory by the
`eval_template` helper in `setup/util.sh`. It wraps `envsubst` and writes
atomically: a temp file is rendered, compared with `cmp -s` against the
destination, and the destination is only replaced when the content has changed.
Any previous destination is archived with a timestamped `.old.<timestamp>`
suffix.

`eval_template` accepts an optional third argument: a shell-format variable
list (e.g. `'$FOO $BAR'`). This controls which variables `envsubst` expands:

- **No third argument** — expands every `$VAR`. Use only for templates whose
  variables are all setup-time values resolved when setup runs (e.g.
  `templates/.gitconfig` with `$GIT_EMAIL`, `$GIT_SIGNINGKEY`, etc.).

- **Explicit variable list** — only the listed variables are substituted; all
  other `$VAR` references are passed through verbatim. Required for templates
  that mix setup-time and runtime shell variables. For example,
  `templates/.zshrc` is rendered with:

  ```bash
  eval_template "$DOTS_REPO/templates/.zshrc" "$HOME/.zshrc" '$GIT_EMAIL'
  ```

  `$GIT_EMAIL` is stamped in at install time; `$HOME`, `$PATH`, `$NVM_DIR`,
  and every other variable are left as literal `$VAR` strings for the shell to
  expand at runtime. This is the same mechanism `envsubst` itself exposes — the
  variable list argument is passed straight through.

When adding a variable to any template, decide whether it is setup-time or
runtime. If the template mixes both kinds, supply the explicit variable list.

### Backup audit and pruning

Setup scripts archive replaced destinations in place with a dots-managed backup
suffix before installing the new file or symlink.
Most backups look like `<destination>.old.YYMMDDHHMMSS`; a few directory setup
scripts use `<destination>.old.YYYYMMDDTHHMMSS`.

Audit backups first:

```sh
bin/dots-backups.sh
```

The audit is a dry run.
It only checks known destinations managed by this repo, reports matching
backups, and prints `WOULD DELETE` only for older backups it can prove are
redundant because they match the current destination or a newer backup for the
same destination.
It always keeps the newest matching backup for each destination and skips
backups whose safety cannot be confidently determined.

To inspect a smaller tree, pass `--root`:

```sh
bin/dots-backups.sh --root ~/.config
```

Prune only after reviewing the audit output:

```sh
bin/dots-backups.sh --prune
```

The prune mode only targets the same exact `.old.<timestamp>` suffixes used by
this repo.
It does not delete unique backups, the newest backup for a destination, or paths
with non-dots backup names.

To also select the newest backup for a known destination when it matches the
current destination, pass `--delete-newest`.
Add `--prune` after reviewing the dry run:

```sh
bin/dots-backups.sh --delete-newest
bin/dots-backups.sh --prune --delete-newest
```

To select every matching backup for known destinations, including unique backups,
pass `--all`.
Add `--prune` after reviewing the dry run:

```sh
bin/dots-backups.sh --all
bin/dots-backups.sh --prune --all
```

Both flags are intentionally explicit and still ignore unrelated paths, source
repos, current dotfiles, and files without dots backup suffixes.

### Contributing

Fork this repo, and add your own templates. Pull requests for updates to setup scripts are welcome!

#### Local development and testing

A Makefile is provided with some commands for testing across various Linux distros:

```sh
make docker-build # build all three Linux variants

# Run the top level setup.sh in a new container, and drop the user into a shell afterwards:
make docker-run-alpine
make docker-run-debian
make docker-run-fedora

# Lint all shell scripts with ShellCheck
make check
```

The `make check` target requires [`shellcheck`](https://www.shellcheck.net/) to be installed in your
environment. It runs ShellCheck with `--severity=warning` so you see actionable warnings and errors
without the noisier informational suggestions.

#### pre-commit hooks

This repository ships with a [pre-commit](https://pre-commit.com/) configuration that runs ShellCheck
before each commit. Enable it locally with:

```sh
pip install pre-commit
pre-commit install
# Optional: run every hook against the whole repository
pre-commit run --all-files
```
