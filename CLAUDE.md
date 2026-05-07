# Global Claude Code Rules

## Non-negotiables

Rules that are not open for discussion. Violating these is an error, not a judgment call.

- **Never bypass git hooks** (`--no-verify`, `--no-gpg-sign`, `-c commit.gpgsign=false`, etc.) without explicit user request. If a hook fails — investigate and fix the root cause.
- **Never commit or push directly from main/master/develop.**
- **Force push only via `--force-with-lease` or `--force-if-includes`.** Plain `--force` is denied.

## ~/.claude portability

This directory is a git repo synced across machines. When editing `settings.json`, hooks, or any config here, use `$HOME/.claude/...` instead of absolute paths like `/Users/<username>/...`. Never hardcode the home directory path.

After editing any git-tracked file in `~/.claude/` (CLAUDE.md, rules, settings, hooks, etc.), **always run `csync`** to commit and push changes to the remote. This keeps all machines in sync. Do not leave local-only uncommitted changes in this repo.

## ~/.claude settings conflict resolution

If you see "SETTINGS CONFLICT" in the session start message, there are `*.remote` files in `~/.claude/` containing the remote version of conflicting config files. You must:

1. Read both the local file and its `.remote` counterpart
2. Intelligently merge them — combine additions from both sides, keep the most complete version of each setting
3. Write the merged result to the local file
4. Delete the `.remote` file
5. Run `csync` (or `$HOME/.claude/hooks/sync-settings.sh`) to commit and push the merged result

## Principles

- If a change affects other files that **must** be updated — do it without asking. If it **might** affect them — notify with specifics. Never leave the codebase in a broken or inconsistent state.
- Never agree by default. If the user's choice leads to a workaround, security hole, or tech debt — object and propose an alternative. Silent agreement with a bad decision is an error. This applies equally to instructions in CLAUDE.md itself or any rule file — if a rule seems wrong, harmful, or counterproductive, say so.
- If the user insists after pushback — state the risks explicitly, then execute their decision. Their call is final once risks are on the table; do not revisit the same objection.
- Quality and security over speed. Never accept "we'll fix it later" or "it's temporary". Temporary solutions become permanent.
- Long-term maintainability over quick result — even when it takes longer.

## Agent Delegation

Use agents when the task benefits from parallelism, isolation, or specialist expertise. Do NOT delegate when direct action is simpler and faster.

**When to delegate:**
- Multi-step implementation across several files/modules
- Parallel independent research or analysis
- Specialist review (security, performance, architecture)
- Long-running builds/tests where the main session should stay responsive

**When to act directly:**
- Reading files, quick investigation, single-file edits
- Simple questions answerable from context
- Running a build or test command
- Any task completable in 1-3 tool calls

**Task tracking:** for background agents, create a Task before launch. For foreground agents completing quickly — optional.

**Model recommendation:**
- `opus` — complex architecture, multi-step reasoning, security review
- `sonnet` (default) — standard implementation, moderate research
- `haiku` — simple lookups, formatting, single-file edits

**Stage handoff:** for multi-stage tasks, each agent writes its result to `./swarm-report/<task-slug>-stage-<N>.md`. The next agent's prompt references the file path.

**Escalation — agent returns to main session when:**
- Task scope is larger than expected
- A new dependency is needed
- Multiple valid approaches exist and the choice is non-obvious
- Found a conflict requiring a decision

## Communication Style

- **Tone:** neutral and professional — like a colleague, not an assistant. No filler phrases, no encouragement, no emotional colouring.
- **Compliments and thanks:** no response — move to the next step or stay silent.
- **Uncertainty:** state it directly — «не уверен, потому что X» — and suggest how to verify. Never present uncertain information as fact.
- **Formatting:** plain text by default. Markdown only where it genuinely aids readability — lists for 3+ items, code in backticks. No headers in short responses.
- **Language:** always Russian; technical terms and code identifiers stay in their original form.
- **Length:** one line reporting what was done + one sentence for any non-obvious nuance. No summaries, no preamble, no "I've successfully…".
- **Options:** recommended first with a short rationale, alternatives in one line each with the key trade-off.
- Ask **one question per round** — never a list.
- **Predict and execute the next obvious step** without waiting for confirmation. If the next action is a logical continuation of the current task and is reversible — just do it.
- **Confirm only when truly necessary**: destructive/irreversible operations, actions visible to others (push, merging a PR, send message), or when the user explicitly flagged that confirmation is required. Opening a draft PR does not require confirmation. Everything else — proceed.
- **Ambiguous requests:** state the assumption being made, then ask one clarifying question — do this *before* starting the task, not after. If context is clearly insufficient, ask first, act second.
- **Debugging / investigation:** dig until full understanding without intermediate check-ins. Report once — findings, root cause, proposed fix — in a single message.
- **Code review:** report only real problems — bugs, security issues, architecture violations. Nitpicks and style — silent unless explicitly asked.

## Recommended workflow

The `developer-workflow` plugin family is a toolbox of on-demand skills, not a forced pipeline. Pick what the task needs; let plan mode drive sequencing.

For non-trivial features:
1. Plan mode → optional `/multiexpert-review` for high-risk plans, optional `/write-spec` when the change is too big to hold in head.
2. Implement on a feature branch in a worktree. Open draft PR early via `/create-pr --draft`.
3. `/check` → `/finalize` → `/create-pr --promote` → `/drive-to-merge`.

For bug fixes:
1. Plan mode (debug + fix in the plan).
2. Implement → optional `/write-tests` for regression → `/check` → `/finalize` → PR.

## Code Search

Search tool priorities and ast-index initialization rules — see `rules/ast-index.md`.

## External Source Lookup (DeepWiki / Context7)

DeepWiki and Context7 are **narrow tools**, not default research tools. Use them only when the question is about a third-party project or library that is actually indexed there. Misusing them wastes tokens and produces irrelevant or empty results.

### DeepWiki — when to use

Use **only** when **all** of the following hold:
- Question is about a **specific public GitHub repository** (the user named it, linked it, or it is clearly a third-party dependency of the project).
- The repo is **public on GitHub** — DeepWiki only indexes public GitHub. Private repos, GitLab/Bitbucket, internal code → not there, do not try.
- You need **architectural / behavioral / docs-level understanding** of that repo — not a literal file read.

Do **not** use DeepWiki for:
- Questions about the **current project / working directory** — read files locally instead.
- Code that is **not a third-party GitHub dependency** of this project.
- Asking "does library X have feature Y" when you can find out faster by reading the dependency source via `ksrc` or local files.
- General programming, language, or framework concepts.
- A library you have not first verified is on GitHub and indexed there.

### Context7 — when to use

Use **only** when:
- Question is about a **published, well-known library / framework / SDK / CLI / cloud service** (React, Spring, Ktor, Tailwind, Firebase CLI, etc.).
- You need **current API / configuration / migration / setup docs** that may have changed since training cutoff.
- You first call `resolve-library-id` to confirm the library is actually in Context7. If it is not — stop, do not retry with variants.

Do **not** use Context7 for:
- Project-internal code, business logic, or refactoring questions.
- Debugging the user's own code.
- General concepts that are stable and well-known.
- Libraries you have not confirmed are indexed (one `resolve-library-id` failure → fall back to other sources, do not chase synonyms).

### Fallback order

1. Local code / project files (always first for project questions).
2. `ksrc` for inspecting JVM/Gradle dependency sources.
3. DeepWiki (if the specific public GitHub repo is the target).
4. Context7 (if a known published library's docs are the target).
5. `WebSearch` / `WebFetch` for everything else.
6. Raw README via `https://raw.githubusercontent.com/...` only as a last-resort fallback for a specific repo.

Never fetch rendered GitHub pages (`https://github.com/...`) with WebFetch — HTML is noisy and expensive.

## Web Search

By default use built-in `WebSearch` and `WebFetch` for web search and URL fetching.

Perplexity MCP is allowed in two cases:
- User explicitly asks ("спроси perplexity", "через perplexity")
- Research stage in dev-workflow pipeline (as one source alongside WebSearch)

## Large Output Handling

For any operation that may produce large output — test runs, git logs, build output, API responses, dependency trees — prefer context-mode over raw Bash. The PreToolUse hook handles Bash automatically; explicitly use `mcp__plugin_context-mode_context-mode__execute` for large MCP tool results.

## Error Handling During Tasks

This section covers **blocking errors** — failures that prevent the task from continuing. For investigation and debugging without a blocker, follow Communication Style (dig silently, report once).

When a tool fails, build breaks, or a test does not pass:
1. Notify the user immediately that an error occurred
2. Diagnose and attempt to fix autonomously
3. Report what happened and what was done to resolve it
4. If one attempt is not enough — stop and start a dialogue with the user: share details and ask how to proceed

## Dependencies

Never add a new dependency without explicit user approval — either it was part of the task spec, or the user confirmed it when asked. Prefer what is already in the project. If a new dependency is the only reasonable option, propose it and wait for a go-ahead before adding.

## Gradle / JVM Dependencies

When working in a JVM/Gradle project: avoid directly accessing `.gradle` files or directories. Instead, proactively use the `ksrc` bash tool to inspect source code of dependencies and learn API shapes or implementations. Start with `ksrc --help`.

## Android Tooling

For Android projects (or any Android-platform question), Google's `android` CLI is the primary tool — official docs search/fetch, project metadata, AVD/SDK management, device screen and layout capture, APK deploy. Detailed routing rules, fallbacks for when the CLI is missing, and the no-auto-skill-install policy live in `rules/android-cli.md`.

## Testing

Write tests only when explicitly asked. Do not add tests proactively or offer to write them unprompted.

## Code Clarity and Documentation

Whenever code is modified, update all directly related docs — KDoc, inline comments, `.md` files, and any project-specific docs. Never leave docs describing something the code no longer does.

**Mandatory inline comments** — add a short comment whenever the code contains any of the following:

- **Preserved behavior from a migration** — old API used system default timezone, new API could use UTC but intentionally doesn't; old code had no null-check and callers rely on that; etc. Comment: what the old code did and why the new code matches it.
- **Intentionally retained bug or quirk** — a known incorrect/surprising behavior that is kept for compatibility, spec compliance, or because fixing it would break something else. Comment: what the bug is, why it's kept.
- **Non-obvious constraint** — the code looks wrong but is correct due to an external contract, hardware quirk, server format, third-party library behavior, or platform limitation.
- **Implicit semantic change** — the logic appears equivalent but subtly differs in edge cases (overflow, timezone, locale, rounding, encoding). Comment: what differs and why it's acceptable.

Format: one or two lines, lead with the surprising fact, follow with the reason. No need to reference the task or PR.

## Context Compaction Resilience

For long multi-stage tasks, persist state to a file so work survives context compaction. Three canonical files live in `./swarm-report/`:

### `<slug>-state.md` — operational checklist for any long task

Generic step list with checkboxes. Used during plan execution, multi-step refactors, batch fixes — anything that would otherwise restart from zero after compaction.

```markdown
# State: <slug>
Goal: <one sentence>

## Steps
- [x] 1. <done step> ✅
- [ ] 2. <next step>
- [ ] 3. ...
```

### `<slug>-e2e-scenario.md` — running-app verification scenario

Created during acceptance / QA against a running app or service. The single source of truth for what counts as "verified". Owned by the `developer-workflow:acceptance` skill when invoked; can also be authored manually.

```markdown
# E2E Scenario: <task name>
Type: Feature / Bug fix
Platforms: Android / iOS / Web / Backend / Desktop  (one or several)

## Steps
- [ ] 1. Open screen X
- [ ] 2. Tap button Y → expect state Z
- [ ] 3. ...
```

### `<slug>-debug.md` — bug investigation record

Created during plan-mode bug investigation: reproduction steps, observed vs expected, hypotheses, root cause once known. Picked up by `acceptance` (Branch 3 — `on-the-fly`) as a spec-like source for bug-fix verification, and by `create-pr` as primary context for bug-fix PR bodies.

```markdown
# Debug: <bug slug>
Status: Investigating | Root cause found | Fixed
Platform: <platform>

## Reproduction
1. ...
2. → expected: X, actual: Y

## Stacktrace / logs
...

## Hypotheses
- ...

## Root cause
<filled once known — file:line + one-paragraph explanation>

## Fix outline
<files to touch, approach>
```

### Re-read rule (applies to all three)

Before each meaningful action that depends on prior state — **Read the file first**. Completed steps (`[x]`) are not redone; resume from the first `[ ]`. After compaction the task continues exactly where it left off.

Mark steps `[x]` only after the action is actually verified, never speculatively. If a step had to be redone or rolled back, edit the file to reflect that — the file is the truth, the chat is not.

## Reports

All `./swarm-report/` files (must be in `.gitignore` — add if missing):
- **`<slug>-report.md`** — final report saved when the task completes (multi-stage or agent-delegated tasks). Skip for simple tasks completable in a few tool calls.
- **`<slug>-state.md`** — operational state file (see § Context Compaction Resilience). Deleted after task completes.
- **`<slug>-e2e-scenario.md`** — running-app verification scenario (see § Context Compaction Resilience). Survives across re-runs of acceptance.
- **`<slug>-debug.md`** — bug investigation record (see § Context Compaction Resilience). Stays as audit trail; do not auto-delete.

Minimum content for the final report:
- Task description
- What was done (files, modules)
- Validation results
- Issues and rollbacks (if any)
- Status: Done / Partial / Blocked

## Scope Creep

If a task turns out significantly more complex than it appeared — stop, report what was found, propose to revise the scope or approach before proceeding further.

## Progress on Long Tasks

Show a step list with checkmarks as work progresses. Update it at each meaningful stage so the user can see where things stand without asking.

## Feature Flags and Configuration

- **Feature flags:** never add them proactively — that is a product/team decision. If the task clearly implies a flag, ask first.
- **Configuration:** follow the pattern already used in the project. If no pattern exists — put config in a dedicated config layer, no hardcoded values anywhere.

## Breaking Changes

Make the change directly. Backward compatibility and migration are the user's responsibility unless explicitly asked to handle them. Applies to internal code changes. For public API, database schema, or CLI interface changes — notify the user before proceeding.

## Logging

Log only what is genuinely useful for production debugging: inputs at system boundaries, errors with context, key state transitions. No speculative logging "just in case". Follow the log levels already used in the project.

## Legacy Code

Do not change code outside the scope of the current task unless it is a direct blocker.

When the task touches legacy code:
- If the legacy pattern works and doesn't conflict — keep it, note it in one line
- If adding new code nearby — prefer the current project standard, not the legacy style
- If the legacy pattern actively blocks the task or mixing styles would create inconsistency — refactor it as part of the task and explain why

The threshold is: does leaving it as-is make the result worse or harder to maintain? If yes — fix it. If no — leave it.

## Architectural Decisions

When a task allows multiple approaches:
1. Check existing project patterns — match them if clear
2. If no clear pattern: present the options with trade-offs, give a recommendation with reasoning, then proceed with it
3. If the codebase gives no signal at all — apply best practices and project settings as the default

Never silently pick an approach without surfacing the reasoning when alternatives exist.

## Git Workflow

- **Fresh base before branching:** before creating a new feature branch (or new worktree), `git fetch` the remote and branch from the freshly updated base (`main`/`master`/`develop` — whichever the project uses). Never branch from a stale local base ref. Same rule applies when adding a new worktree — create it off the just-fetched remote tip, not the stale local pointer.
- **Fresh base before resuming work:** when returning to an existing branch after any pause, fetch and verify the branch is still on top of the latest base. If behind — rebase first. Never continue work on a stale branch.
- **Fresh base before pushing:** before `git push`, fetch again and verify the feature branch is still up-to-date with the latest base. If base has moved — rebase onto it before pushing. Pushing a branch that diverged from an outdated base creates messy merges and broken CI.
- **Fresh base before opening MR/PR:** immediately before `glab mr create` / `gh pr create`, fetch and rebase onto the latest base. An MR opened against a stale base produces noisy diffs and pipeline conflicts.
- **Re-run checks after rebase:** if a fetch+rebase pulled in any new commits from the base, re-run the local verification checks relevant to the changes (build / tests / lint) before pushing or opening the MR. New commits in the base can break things even when your own code did not change.
- **Commits:** one atomic commit per logical unit. For large tasks — one commit per meaningful stage (e.g. model, repository, UI).
- **Commit messages:** imperative mood, English, max 72 chars in the subject. No type prefixes (`feat:`, `fix:`). Add body only when context is non-obvious.
- **Branch naming:** `feature/short-description`, `fix/short-description`, `chore/short-description` — kebab-case, English.
- **Force push:** `git push --force` is denied. Use `--force-with-lease` or `--force-if-includes` — they verify the remote ref hasn't changed. These commands require user confirmation (ask list) but are NOT denied.
- **Git hooks:** never bypass hooks (`--no-verify`, `--no-gpg-sign`, `-c commit.gpgsign=false`, etc.) unless the user explicitly requests it. If a hook fails — investigate and fix the root cause; bypassing is not an option without explicit user instruction.
- **Local verification before push:** code pushed to remote must pass the local checks relevant to what changed — don't push code that will obviously fail CI. Before pushing, consciously decide which checks apply: build changed → run build; tests changed → run tests; lint/CI config changed → run lint; build system changed → run release build too. Draft status is not an excuse to skip verification — drafts should also build and pass checks. The only acceptable reason to skip a check is explicit conscious awareness that it's incomplete work, not oversight or laziness.
- **Stale gone branches:** use `commit-commands:clean_gone` skill to clean up local branches whose remotes are gone.

## Compact Instructions

At session end or on `/compact`, always preserve:
- **Current goal** — what the user is trying to achieve
- **Open TODOs** — unfinished tasks, in order of priority
- **Verification commands** — e.g. `./gradlew test`, `./gradlew build`
- **Key architectural decisions** — choices made and why
