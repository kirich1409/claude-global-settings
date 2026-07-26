# Tracker operations — PR/MR, issues, and the project board

How to work with PRs/MRs, issues, and the Projects board without hanging. Command and GraphQL
detail lives **in the scripts**, not here — read a script's header block when you need the
exact recipe.

## Toolkit — `$HOME/.claude/scripts/gh/`

Idempotent, timeout-safe helpers. Prefer them over raw `gh project` or hand-written GraphQL.
Every script wraps its network calls in `gh_with_timeout` from `_common.sh`, so a hung API
aborts instead of freezing the agent.

| Script | What it does |
|---|---|
| `transition_status.sh <issue> <status>` | Moves an issue on the board (Projects v2 via GraphQL) or falls back to labels. `--dry-run` resolves without writing. |
| `get_completion_signal.sh <issue>` | Is the issue complete? (merged PR > open PR > none) |
| `get_dependencies.sh <issue>` | Blocking dependencies: sub-issues plus "blocked by #N" / "depends on #N". |
| `list_issues.sh` / `fetch_issue.sh` | Query/fetch issues (state, labels, body, node id, timestamps). `list_issues.sh` returns `updated_at` for the whole list — staleness without extra calls; bodies are deliberately omitted. `fetch_issue.sh --with-comments` adds the thread (`author`, `created_at`, `body`, `edited`) — off by default, and comment bodies are not size-capped. |
| `add_comment.sh` / `link_pr.sh` | Marker-idempotent comment / PR link. |

## Idempotency — every tracker mutation must be resume-safe

A session can be compacted, rewoken (`ScheduleWakeup`), or restarted. Mutations must not
duplicate or apply twice. Two mandatory patterns:

- **Read before write** for status: read current state, write only if it differs (the scripts
  return `action: noop` when already there).
- **Hidden marker** for comments and links: scan for `<!-- issue-manager:<key> -->` before
  posting; skip if present. Never post a tracker comment without checking the marker.

## The board — move the card at every stage

Keep the board in sync with reality.

| Stage | Board status | Trigger |
|---|---|---|
| Work started / draft PR opened | **In Progress** | `create-pr --draft` |
| PR ready for review | **In Review** | `create-pr --promote` |
| Merged | **Done** | post-merge |
| Blocked | (label `status:blocked`) | a genuine blocker raised |

Move it with `transition_status.sh <issue> <in-progress|in-review|done|blocked>` — do not
hand-write `gh project item-edit` or GraphQL. The script finds the linked Project v2 itself
and falls back to open/closed plus `status:*` labels when there is no project or no
permission. Moving the card is the most frequently forgotten step of the PR pipeline.

## Platform abstraction — describe the action, not the CLI

GitHub ↔ GitLab. Detect the platform from the remote host (see `setup.md`), then map: `gh` ↔
`glab`, `gh pr` ↔ `glab mr`, `gh api graphql` ↔ `glab api`. Think "move the card" / "is it
merged" / "re-request review" and pick the CLI from the detected platform; never assume
`github.com`.

## Anti-hang — never block the session on a long operation

- All scripted `gh` calls are timeout-bounded (`_common.sh`). When writing new `gh` calls
  outside the toolkit, wrap them too: a synchronous `gh` without a timeout will freeze the
  agent if the API hangs.
- **Never run blocking watchers in the main session:** `gh run watch`, `gh pr checks --watch`,
  and `gh run watch --exit-status` block for the whole CI duration. Delegate to a background
  task or subagent, poll with `ScheduleWakeup`, or hand the waiting to the platform (see
  `autonomy.md`).
- Treat `pending` as "keep waiting", never as a failure.
