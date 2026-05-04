When creating Jira tickets, follow the format "#### Metadata\n ... #### Problem\n ... #### Solution\n ...". If possible, include a prefix in the title that indicates which service the change is related to, e.g. "[BBBS] remove unused ...". Some relevant services include core (Bitbucket core repo), frontbucket, BBBS (bitbucket-billing-service), dss-* services (like dss-repository-processor). Use the related repo's directory name or service descriptor, if available, to figure out the relevant service. If no service is relevant, omit the tag prefix. Story points are in a custom field called `customfield_10117` on softwareteams Jira/BBCEEP tickets; 2 points is a typical ticket estimate, with trivial tickets being 1 point and more complex tasks being 3. Rarely should we have > 3 points on a ticket; this indicates the work should be further split up. Stories can be used to group sets of tasks, with a blocks/blocked by relationship. Never use sub-task type work items due to how they behave across sprints.

---

When classifying Jira tickets with Engineering Work Taxonomy (EWT) labels, apply exactly one
of these labels based on the work's primary outcome:

- `ewt-ctb-feature` — new features, roadmap initiatives, new platform capabilities
- `ewt-ctb-improve-existing` — perf/reliability/security improvements, compliance uplifts, PIR improvement actions, architecture redesign
- `ewt-ctb-awesome-tools` — tooling benefiting orgs/pillars outside your own
- `ewt-dp-empowered-teams` — tech debt, test gaps, local dev pain, reducing RtB costs (self-selected, own team)
- `ewt-dp-amazing-engineering-culture` — adopting standards, golden images, improving team processes (own team)
- `ewt-rtb-service-operations-and-tech-entropy` — incidents, PIR priority actions, CSS escalations, vuln fixes, dependency upgrades, alert tuning
- `ewt-rtb-organic-growth` — scaling work driven by organic company growth (not architectural redesign)

When ambiguous, classify by the work's primary driver/outcome.

---

Feature flag cleanup tasks should be reported in a straightforward task, similar to "Metadata\n\nhttps://switcheroo.atlassian.com/ui/gates/15a6353f-42ed-47b1-99f8-95383b1e787f/key/bbceep-5456-bbbs-allow-null-recharge-date\n\nProblem\n\nStale flag, on at 100% for all users as of 2026-01-16\n\nSolution\n\nRemove the flag references in our code\n\nAfter deploy, archive the flag"

Create a branch for each Jira ticket, with the format `akofink/BBCEEP-1234-<description>`. Do not transition Jira tickets to new statuses unless explicitly asked to do so.

When creating commits, title them using conventional commit format, including the Jira ticket number likely within the branch name, or NONE, e.g., "feat: BBC-123 add new feature", "fix: BBCEEP-123 resolve bug", "docs: NONE update documentation", "chore: ABC-123 bump package version", "chore: BBCEEP-123 remove dead code" etc. and use the following commit body format "Metadata\n\n ... Problem\n\n ... Solution\n\n ..." since git ignores lines starting with "#". Markdown syntax is otherwise encouraged, especially backticks for code keywords or blocks. Use git commit best practices, including using the imperative mood and not past tense in the solution. By default, commits are signed with the author's GPG key, but if you need to disable signing for a specific commit, you can use the `--no-gpg-sign` flag with the `git commit` command. The commit message is used as the default PR description in markdown on Bitbucket Cloud; unordered lists require an additional newline proceeding them to render properly, for example. Do not ever push commits to any remote unless asked to do so.

Default workflow after changing tracked files is: edit, verify, stage, commit, then final response. Do not return control to the user with uncommitted changes unless the user explicitly asked not to commit, the task is intentionally incomplete, or committing is blocked; if blocked, explain why and include the exact next command to run.

Never post comments or replies on Bitbucket pull requests. Reading PR comments is fine and often necessary for context. When the operator wants a response delivered to a thread, draft the reply text in chat (or in an unstaged scratch file in the worktree) so they can paste it into Bitbucket themselves; never use any MCP `bitbucketPullRequest` action with `action=comment` (or any other write action that surfaces in the PR UI such as `approve`, `merge`, `edit`) without an explicit instruction to do exactly that.

This is a professional codebase; do not include excessive obvious comments. Function or class level
comments are encouraged on public interfaces.

When writing feature flagged code, consider that the flag will be cleaned up within a week or two. Later flag cleanup is easier to review when (1) the flag string is used as a literal instead of assigned to a constant, and (2) overridden true/ON tests do not mention the flag state (these tests will simply be kept on flag cleanup; updating test function definitions adds unnecessary diff).

When writing tests for code that is feature flagged, include tests for both the enabled and disabled states of the feature flag. Use descriptive test names that clearly indicate what is being tested and the expected outcome but does not mention the flag state itself. The flag overrides speak for themselves, and this reduces the changes necessary to later clean up the flag. Flag names must not exceed 50 characters. Choose flag names with service and jira ticket prefix, like `bbc-bbceep-1234-<description>`.

When creating splunk queries, use macros with backticks to get logs for a given service, like "`micros_bitbucket-billing-service` env=prod-east ..."

When linking Jira work items (e.g., "blocks"/"blocked by" relationships), the user can use `acli jira workitem link create --out <OUTWARD-KEY> --in <INWARD-KEY> --type <TYPE> --yes`. If you have no tools available to do the linking, provide these commands back to the user for manual execution. Available link types can be listed with `acli jira workitem link type`. For "blocks" relationships, the inward issue blocks the outward issue (e.g., --out BBCEEP-5692 --in BBCEEP-5707 --type Blocks means BBCEEP-5707 blocks BBCEEP-5692).

When rebasing chained branches, the `git rebase --onto <previous-branch> HEAD~1` command is useful.

---

When creating Jira issues via the Atlassian MCP tools (`create_jira_issue`), do **not** pass the `assignee` parameter — user lookup by email or display name fails silently and causes the entire creation to fail without an error. Create the issue unassigned and let the user self-assign. Also note that `create_jira_issue` returns a generic "Could not find user" message but the issue may or may not have actually been created — always verify with a JQL search after a failed attempt before retrying.

When creating or updating Confluence pages via the Atlassian MCP tools (`create_confluence_page` / `update_confluence_page`), the body must use the LLM-optimised HTML format documented in the `confluence` skill — **not** the legacy storage format with `<ac:structured-macro>` tags. Storage-format tags are not parsed; they round-trip as escaped text (`&lt;ac:structured-macro …&gt;`) and render as visible junk on the page. Specifically: use `<div data-type="panel-info|warning|note|success|error"><p>…</p></div>` for panels, `<pre><code class="language-LANG">…</code></pre>` for code blocks (escape `<` `>` `&` inside), `<details><summary>…</summary>…</details>` for expanders, and the `data-type=…` attributes from the skill for tasks/decisions/layouts. Always read the `confluence` skill before authoring or editing any Confluence page so this is fresh.

The working `parent_url` form for placing a page under a Confluence **folder** via `create_confluence_page` is the page-style URL with the folder id substituted as the page id, e.g. `https://hello.atlassian.net/wiki/spaces/<slug>/pages/<folder-id>`. The `…/folder/<folder-id>` and cloud-space-id (`/spaces/<uuid>/…`) forms succeed silently but place the new page at space root instead of inside the folder — always verify placement with `view_confluence_ancestors` or by re-fetching the parent's children after creation. Folder creation/deletion and page deletion are not exposed by the Atlassian MCP — for cleanup, rename the stale page (titles must be unique per space) with a `(deprecated, …)` suffix and ask the operator to delete in the UI.

If asked to work within a worktree and there is no clear worktree setup for the given working space, use the directory structure at ~/dev/worktrees/<repo-name>/BBCEEP-1234<-optional-description>/, i.e. `git worktree add ~/dev/worktrees/$(basename $PWD)/SAI-20888 akrishnamoorthy/pmr-routing-for-remaining-dd-apis`.

Global notes/context for various Jira tickets, repos, and services is at ~/dev/repos/notes/, within which has core-notes/ for Bitbucket Cloud related notes, and dss-notes/ for DSS services related notes. These notes are used for both tracking the work as well as providing rounds of review back to the agent with feedback prior to creating Jira tickets, PRs, or Confluence docs.

There are generic multi-repo workspaces at ~/dev/workspaces.

---

`~/dev/repos/notes/WORKING_STATE.md` is the canonical agent working-state board for the human operator. Every agent run that has a local code worktree and branch (in any repo other than the notes repo itself) must keep this file current so the operator has a single place to see which agents are working on code and where. Skip the board for pure docs/notes work, epics or other tracking-only tickets, and pre-branch explorations. On start, read it; before finishing a turn that materially changes state (branch created, PR opened/updated, blocked, handed off, merged), update the relevant entry.

The board is structured as a single `## Active` section split into three `###` subsections — `BBC`, `DSS`, and `Other` — each holding a flat unordered list. File entries under `BBC` for the bitbucket monolith and tightly-coupled satellites (e.g. `bitbucket-billing-service`, `frontbucket`), under `DSS` for any `dss-*` service repo, and under `Other` for everything else. Keep all three subsections present even when empty so the structure is predictable; place `_(no active agent runs)_` under any empty subsection. No tables, no inline instructions, no markdown link wrapping (the operator reads the file unrendered) — so it stays human-readable as parallel work scales. Each entry is one top-level bullet whose text is `<TICKET-KEY> — <short description>` (e.g. `BBCEEP-1234 — Remove unused field`), with a shallow nested list of fields: Ticket (raw Jira URL), Repo, Branch, Worktree (absolute path), PRs (raw Bitbucket links, comma-separated; omit field if none), Status (short phrase), Notes (path under `~/dev/repos/notes/` to the primary notes doc), Session (rovodev session UUID — find it by listing `~/.rovodev/sessions/` by mtime and picking the latest dir whose `metadata.json` has a `workspace_path` matching the current working directory or its repo root), Updated (`YYYY-MM-DD HH:MM`).

Do not remove an entry until the work is merged to the respective repo's main/master branch. A separate cleanup pass may sweep stale entries by checking each branch against its base — see the working-state-cleanup skill in the notes repo at `~/dev/repos/notes/.rovodev/skills/working-state-cleanup/SKILL.md`. Individual feature agents should not preemptively delete their own entries. The board is a status pointer only — decisions, analyses, design docs, and review feedback continue to live under `~/dev/repos/notes/core-notes/`, `~/dev/repos/notes/dss-notes/`, or dated scratch directories and are referenced from the entry's `Notes` field. The full schema and update rules live in `~/dev/repos/notes/AGENTS.md`. Updates to `WORKING_STATE.md` follow the notes repo's standard rule of always being committed (no pushing without explicit user request).
