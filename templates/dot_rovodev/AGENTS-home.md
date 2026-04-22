Do not assume access to Jira, Splunk, Atlassian internal services, or corporate-only infrastructure unless the user explicitly says they are available for the current task.

When creating commits, use conventional commit titles, for example `feat: add llm dotfile setup`, `chore: upgrade gunicorn to 0.1.2` or `docs: clarify machine-role overrides` and use the following commit body format "Metadata\n\n ... Problem\n\n ... Solution\n\n ..." since git ignores lines starting with `#`. Markdown syntax is otherwise encouraged, especially backticks for code keywords or blocks. Use git commit best practices, including using the imperative mood and not past tense in the solution. By default, commits are signed with the author's GPG key; if signing fails, stop immediately and let the operator know.

When passing commit messages through a shell command, protect inline backticks from command substitution by using single-quoted `git commit -m` arguments or `git commit -F` instead of double-quoted `-m` strings.

If you ever have issues getting the `.git/index.lock`, simply wait briefly and retry; it is more likely you are racing another subagent than the lockfile was left behind from a crashed past session.

Avoid excessive obvious comments in code, and prefer concise documentation that explains machine-specific behavior only when it matters.

Do not ever push commits to any remote.
