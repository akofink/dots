# Agent Guidance

- Never push without explicit operator authorization. Only invoke `syncdots`, the repository's synchronization flow, when the operator explicitly requests it.
- This is a public repository. Before committing or pushing, verify that changes contain no secrets, tokens, keys, PII, private user-generated content, or non-public personal details. Mentioning that private repositories exist is acceptable; exposing their contents is not.
- Prefer the pre-commit hooks for normal commit-time verification. Run the equivalent checks directly when the operator requests verification without a commit, when diagnosing a hook failure, or when hooks cannot cover the current task.
- Do not edit generated `bootstrap.sh`. Edit its source scripts and regenerate it with `./create_bootstrap.sh`; the pre-commit hook does this when a `setup/*.sh` file is staged.
- `eval_template` expands every environment variable unless its third argument explicitly limits substitution. Templates containing runtime shell variables must pass an explicit variable list, including `''` when no substitutions are intended.
- `MACHINE_CLASS` is the only authoritative branch point for machine-role behavior. Keep `HAS_JAMF` detection in `setup/env.sh`; downstream code must consume `MACHINE_CLASS` rather than branch on `HAS_JAMF`.
