# Agent guidance for the dots repo

This is a personal dotfiles and machine-setup automation repository. All setup
logic is pure Bash; there is no build system beyond a thin Makefile.

## Commit conventions

Use conventional commit titles (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`).
Commit body format:

```
Metadata

...

Problem

...

Solution

...
```

Use the imperative mood. Protect inline backticks from shell substitution by
using single-quoted `-m` strings or `git commit -F`. Commits are signed with
GPG by default; if signing fails, stop and report it. Do not push to any remote.

Default workflow: edit → stage → commit → respond. Rely on the pre-commit
hooks to run checks during commit rather than running `make check` manually
first, unless diagnosing a hook failure or the user explicitly asks for a
separate verification command. Do not leave tracked files uncommitted unless
the task is intentionally incomplete or blocked.

## Architecture overview

```
bootstrap.sh          # Generated; curl-pipeable entry point
create_bootstrap.sh   # Regenerates bootstrap.sh from setup/ sources
setup.sh              # Orchestrator: sources modules in order
setup/                # Module and helper scripts
templates/            # Dotfile sources rendered via eval_template/envsubst
Makefile              # lint (make check), docker testing, clean
```

### Module guard pattern

Every script that should run at most once per shell session exports a
`*_SETUP_COMPLETE` guard variable at its end (e.g. `export LLM_SETUP_COMPLETE=1`)
and checks it at the top before proceeding. This makes scripts safe to source
individually or as part of the full chain without re-running work.

`setup/clean.sh` unsets all guards. Use `eval "$(make clean)"` to reset state
in the current shell when iterating on scripts.

Not all module scripts currently export their own guard; `vim`, `tmux`, `zsh`,
`rbenv`, and `tmuxinator` rely on `REPOS_SETUP_COMPLETE` from their dependency
chain rather than tracking their own completion. Adding per-module guards to
those scripts would make the pattern consistent.

### Template system

Templates live in `templates/` and are rendered to the home directory by
`eval_template` (defined in `setup/util.sh`).

`eval_template` wraps `envsubst` and accepts an optional third argument: a
shell-format variable list string (e.g. `'$FOO $BAR'`). This controls which
variables `envsubst` expands:

- **No third argument** — envsubst expands every `$VAR` in the template.
  Use this only for templates whose variables are all setup-time values
  (e.g. `templates/.gitconfig`, which contains only `$GIT_EMAIL`,
  `$GIT_SIGNINGKEY`, `$GITHUB_USER`, `$GIT_CREDENTIAL_HELPER`, and `$HOME`).

- **Explicit variable list** — only the listed variables are substituted;
  all other `$VAR` references are passed through verbatim. Use this for
  templates that mix setup-time variables with runtime shell variables.
  Example: `templates/.zshrc` contains `$GIT_EMAIL` (setup-time) alongside
  `$HOME`, `$PATH`, `$NVM_DIR`, etc. (runtime). It is rendered with:
  ```bash
  eval_template "$DOTS_REPO/templates/.zshrc" "$HOME/.zshrc" '$GIT_EMAIL'
  ```
  This stamps the git email in at install time while leaving every other
  shell variable as a literal `$VAR` for the shell to expand at runtime.

When adding a variable to a template, decide whether it is a setup-time value
(resolved from the environment when setup runs) or a runtime value (resolved
by the user's shell each time). If the template mixes both, pass the explicit
variable list so runtime variables are not clobbered.

### bootstrap.sh drift

`bootstrap.sh` is a generated file concatenated from `setup/env.sh`,
`setup/util.sh`, `setup/git.sh`, and `setup/repos.sh` by `create_bootstrap.sh`.
A pre-commit hook runs `create_bootstrap.sh` automatically whenever any
`setup/*.sh` file is staged, so the bootstrapper stays in sync. The hook
stages the regenerated `bootstrap.sh` alongside the source changes.

Do not edit `bootstrap.sh` directly; edit the source scripts and let the
hook regenerate it.

### Machine-role system

Machine role is expressed as a string variable `MACHINE_CLASS` (values: `work` | `personal`).
It is set in `setup/env.sh` and defaults to `work` on Jamf-managed hosts (`HAS_JAMF=1`) and
`personal` everywhere else. It drives git identity, GitHub user, and which LLM agent
instruction template is deployed.

`MACHINE_CLASS` is the single authoritative branch point for role-dependent behaviour. Do
not add new logic that branches on `HAS_JAMF` directly; keep the detection logic in
`env.sh` and consume `MACHINE_CLASS` downstream.

The design is intentionally open-ended: `MACHINE_CLASS` is a string, not a boolean, so
additional classes (e.g. `server`, `container`) can be introduced without changing the
branching shape. When a third class is needed, add it to `env.sh`'s auto-detection logic,
add the corresponding template or behaviour in the relevant module, and document the new
value here.

### No remote CI

There is no hosted CI pipeline. ShellCheck runs locally via `make check` and
as a pre-commit hook. All Docker-based cross-distro testing is manual
(`make docker-run-{alpine,debian,fedora}`).
