# dots

Dotfiles plus installers. Run the top-level `./setup.sh` to install the curated defaults, or run any
module script individually.

## Modules

- vim
- tmux
- zsh
- rbenv
- tmuxinator

Additional helpers live under `setup/` (e.g., `git.sh`, `ssh.sh`, `nvim.sh`) and can be run directly.

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

The top-level `setup.sh` orchestrates a curated subset of modules—currently `vim`, `tmux`, `zsh`,
`rbenv`, and `tmuxinator`. Feel free to tailor that list or run any other module script directly.

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
