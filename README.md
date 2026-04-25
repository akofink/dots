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
- tmuxinator
- glow

Additional helpers live under `setup/` (e.g., `git.sh`, `ssh.sh`, `nvim.sh`) and can be run directly.

Machine-role behavior is driven by shared environment detection in `setup/env.sh`. Jamf-managed hosts
default `HAS_JAMF=1` and therefore `IS_WORK_MACHINE=1`; override those env vars before running setup if
you need to force personal or work defaults on a given machine or in a container.

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
`opencode`, `rbenv`, `tmuxinator`, and `glow`. Feel free to tailor that list or run any other module
script directly.

#### opencode module

`bash setup/opencode.sh` installs opencode from the local source checkout at `~/dev/repos/opencode`.
It clones `https://github.com/akofink/opencode.git` on the `customizations` branch when missing, keeps
that branch fast-forwarded, ensures `bun` is available, and installs the managed launcher at
`/usr/local/bin/opencode`.
When rebuilding the local binary, the launcher sets `OPENCODE_VERSION=9999.0.0` by default so the
custom build is treated as current by opencode update checks. Override with `OPENCODE_BUILD_VERSION`
when a different local build version is needed.

#### Ubuntu / WSL2 notes

WSL2 system-level config is included as examples only:

- `templates/wsl/wsl.conf`
- `templates/windows-home/.wslconfig`

Those files usually need to be applied manually to `/etc/wsl.conf` and `%USERPROFILE%/.wslconfig`,
then WSL restarted.

#### LLM config module

`bash setup/llm.sh` renders a small managed set of agent configs:

- `~/.config/opencode/AGENTS.md`
- `~/.codex/config.toml`
- `~/.codex/AGENTS.md`
- `~/.codex/instructions.md`
- `~/.codex/rules/dots.rules`
- `~/.rovodev/config.yml`
- `~/.rovodev/AGENTS.md`

The Codex rules file is a repo-managed baseline for portable allow-prefix rules. Keep machine-specific or
task-specific approvals in separate files such as `~/.codex/rules/default.rules`; `setup/llm.sh` will not
overwrite those.

Shared agent instructions intentionally diverge by machine role:

- personal machines get a lightweight template that avoids Jira, Splunk, and other corporate-only assumptions
- work machines (`IS_WORK_MACHINE=1`) get the Atlassian-specific agent guidance

The shared RovoDev config is intentionally conservative so it works across home machines, work laptops,
and containerized setups without assuming proprietary integrations are always reachable.

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
