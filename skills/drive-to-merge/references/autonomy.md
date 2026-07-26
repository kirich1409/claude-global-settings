# Merge autonomy and anti-stall

How to stay autonomous while driving a PR/MR to merge without hanging, and how that differs
between repositories. Mechanics live in `tracker-ops.md`.

## The stalling problem

An agent waiting for a merge often simply stops: it hangs in a CI poll loop or runs into a
manual merge gate. Two remedies, in order of preference.

## 1. Hand the waiting to the platform (native auto-merge) — preferred

Instead of polling CI and babysitting, set the PR/MR to auto-merge and **switch to another
task**. The platform merges once checks pass and review is approved:

- GitHub: `gh pr merge <PR> --auto --squash` (needs auto-merge enabled plus branch protection).
- GitLab: `glab mr merge <IID> --when-pipeline-succeeds` (respects the merge train if enabled).

This removes the wait entirely. **Whether it is allowed is a project policy decision** — see
below.

## 2. If waiting is unavoidable, wait non-blockingly

Never block the session. Poll once with `gh pr view --json
statusCheckRollup,reviewDecision,mergeable,mergeStateStatus,isDraft,state`, classify, then
`ScheduleWakeup` (cache-window discipline: ≤270s or ≥600s, avoid 280-550s). Cap consecutive
no-change polls and report the blocker instead of looping forever.

## Project-aware policy — read it, don't hardcode it

Autonomy is not the same in every repo. Read the policy from the project layer
(`<repo>/CLAUDE.md`, "PR/MR policy" section); if absent, infer from the profile below and
state the assumption explicitly.

| | Personal GitHub (free) | Team GitLab / shared repo (cautious) |
|---|---|---|
| Native auto-merge | allowed by default | **only with explicit consent** — a silent MWPS/merge train can block the team's queue or pipeline |
| `--auto` gate per round | on by default | off — preserve manual review each round |
| Manual merge gate | may be relaxed | **mandatory** |
| Pre-push checks | light | run the full local `check` before every push |
| `--force-with-lease` | fine | careful — it drops others' approvals; re-request review afterwards |
| Parallelism | aggressive | conservative; respect the merge queue and others' work |

Default for any non-personal or unknown-owner repo: **cautious**. When it is unclear which
profile applies, ask once, then record the answer in the repo's `CLAUDE.md`.

## Offer autonomy up front

On spotting a long wait ahead (CI ≥ 5 min, or review pending), proactively offer the
autonomous path — "set auto-merge and switch to another task?" — instead of silently hanging.
Don't make the user remember `--auto` on their own.

## Working several PRs in parallel

- One worktree per PR (`Agent(isolation: worktree)`) — parallel edits without disk conflicts.
- For long cross-session babysitting of many PRs, use a cron routine: "every N minutes, advance
  ready PRs, fix failed ones". It survives session end reliably.
- With native auto-merge on, parallel babysitting is mostly unnecessary — the platform
  finishes each PR itself.
