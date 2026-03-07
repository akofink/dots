When working on personal machines, prefer local tooling, open-source services, and repository-native workflows.

Do not assume access to Jira, Splunk, Atlassian internal services, or corporate-only infrastructure unless the user explicitly says they are available for the current task.

When creating commits, use conventional commit titles with `NONE` when there is no ticket, for example `feat: NONE add llm dotfile setup` or `docs: NONE clarify machine-role overrides`. Do not ever push commits to any remote unless asked to do so.

Keep changes pragmatic and low-ceremony. Avoid excessive obvious comments in code, and prefer concise documentation that explains machine-specific behavior when it matters.
