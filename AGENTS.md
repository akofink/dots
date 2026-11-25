# Agent Guidance

- Create a branch or worktree under `~/dev/worktrees/dots/<slug>/` for each change. After verification and a path-scoped commit, integrate the task commits into clean canonical `main` (fast-forward when possible), then run `syncdots`. `syncdots` synchronizes canonical branches; it does not merge task branches.
- Scoped integration/publication and normal `syncdots` behavior, including managed pruning, have standing approval without a separate operator checkpoint. This named flow may pull with rebase and push; never substitute raw `git push`. Preserve dirty/in-progress state, conflicts, synchronization locks and resource-retention holds; use `--no-prune` when needed to preserve held resources and evidence.
- This is a public repository. Before committing or pushing, verify that changes contain no secrets, tokens, keys, PII, private user-generated content, or non-public personal details. Mentioning that private repositories exist is acceptable; exposing their contents is not.
- Tracked git hooks in `.githooks` run ShellCheck on commit and before every push (including direct pushes to `main`), as CI does. `setup/git.sh` and `bin/cloud-session-setup.sh` enable them through `bin/install-git-hooks.sh`; run it yourself in a checkout that lacks them (`git config core.hooksPath` is empty). Never bypass them with `--no-verify`; fix the finding.
- Prefer the pre-commit hooks for normal commit-time verification. Run the equivalent checks directly when the operator requests verification without a commit, when diagnosing a hook failure, or when hooks cannot cover the current task.
- Prefer `xh` for API calls, HTTP endpoint testing, and other HTTP requests.
- Prefer `rg` (ripgrep) for file and content searches instead of `find` or `grep`.
- Do not edit generated `bootstrap.sh`. Edit its source scripts and regenerate it with `./create_bootstrap.sh`; the pre-commit hook does this when a `setup/*.sh` file is staged.
- `eval_template` expands every environment variable unless its third argument explicitly limits substitution. Templates containing runtime shell variables must pass an explicit variable list, including `''` when no substitutions are intended.
- `MACHINE_CLASS` is the only authoritative branch point for machine-role behavior. Keep `HAS_JAMF` detection in `setup/env.sh`; downstream code must consume `MACHINE_CLASS` rather than branch on `HAS_JAMF`.

## Cloud session start

In a cloud session (`CLAUDE_CODE_REMOTE=true` or `CODEX_ENVIRONMENT_ID` set), before other work bring the attached checkouts up to date and run the cloud setup, then read `agents/global-personal.md` in the notes checkout. This block is self-contained on purpose so a stale checkout can bootstrap itself; keep it stable.

```sh
for r in /workspace/*/ /home/user/*/; do [ -e "$r/.git" ] && [ -z "$(git -C "$r" status --porcelain)" ] && git -C "$r" fetch -q origin main && git -C "$r" merge -q --ff-only origin/main; done
bash "$(ls -d /workspace/dots /home/user/dots 2>/dev/null | head -1)/bin/cloud-session-setup.sh"
```
