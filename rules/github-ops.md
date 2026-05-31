# GitHub / GitLab Tracker Operations

How agents work with PRs/MRs, issues, and the Projects board correctly and without hanging.
This file is the always-on core; **command/GraphQL detail lives in the scripts**, not here — read a
script's header block when you need the exact recipe.

## Toolkit — `$HOME/.claude/scripts/gh/`

Idempotent, timeout-safe helpers (extracted from the retired `issue-manager`). Prefer them over raw
`gh project` / hand-rolled GraphQL. Every script wraps its network calls in `_common.sh`'s
`gh_with_timeout`, so a hung API aborts instead of freezing the agent.

| Script | Does |
|---|---|
| `transition_status.sh <issue> <status>` | Move issue on the board (Projects v2 via GraphQL) or labels-fallback. `--dry-run` resolves without writing. |
| `get_completion_signal.sh <issue>` | Is the issue done? (merged PR > open PR > none) |
| `get_dependencies.sh <issue>` | Blocking edges: sub-issues + "blocked by #N" / "depends on #N". |
| `list_issues.sh` / `fetch_issue.sh` | Query / fetch issues (state, labels, body, node id). |
| `add_comment.sh` / `link_pr.sh` | Marker-idempotent comment / PR linkage. |

## Idempotency — every tracker mutation must be resume-safe

A session can be compacted, re-woken (`ScheduleWakeup`), or re-run. Mutations must not duplicate or
double-apply. Two enforced patterns:

- **Read-before-write** for status: read current state, write only if it differs (the scripts return
  `action: noop` when already there).
- **Hidden-marker** for comments/links: scan for `<!-- agent:<key> -->` before posting; skip if present.
  Never post a tracker comment without a marker check.

## Board (GitHub Projects v2) — move the card at every stage

Keep the board in sync with reality. Canonical state machine and where it's driven:

| Stage | Board status | Trigger |
|---|---|---|
| Work started / draft PR opened | **In Progress** | `create-pr --draft` |
| PR ready for review | **In Review** | `create-pr --promote` |
| Merged | **Done** | post-merge |
| Blocked | (label `status:blocked`) | true blocker raised |

Move via `transition_status.sh <issue> <in-progress|in-review|done|blocked>` — do not hand-write
`gh project item-edit` / GraphQL. The script auto-detects the linked Project v2, falls back to
open/closed + `status:*` labels when no project (or no permission). Don't forget the move — it is the
most-forgotten step of a PR pipeline.

## Platform abstraction — describe the action, not the CLI

GitHub ↔ GitLab. Detect platform from the remote host (see `drive-to-merge/references/setup.md`), then
map: `gh` ↔ `glab`, `gh pr` ↔ `glab mr`, `gh api graphql` ↔ `glab api`. Think "move the card" /
"is it merged" / "re-request review" — pick the CLI by detected platform, never assume `github.com`.

## Anti-hang — never block the session on a long op

- All scripted `gh` calls are timeout-bounded (`_common.sh`). When writing new `gh` calls outside the
  toolkit, wrap them too — a synchronous `gh` with no timeout freezes the agent if the API stalls.
- **Never run blocking watchers in the main session:** `gh run watch`, `gh pr checks --watch`,
  `gh run watch --exit-status` block for the full CI duration. Delegate to a background task/subagent,
  or use `ScheduleWakeup` polling, or delegate the wait to the platform (see [[github-merge-policy]]).
- Treat `pending` as "wait", never as "fail".
