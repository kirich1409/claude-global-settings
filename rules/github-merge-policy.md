# PR/MR Merge Autonomy & Anti-Stall Policy

When driving a PR/MR to merge, how to stay autonomous without stalling — and how that differs per
project. Companion to [[github-ops]] (mechanics) and the `drive-to-merge` skill.

## The stall problem

An agent waiting for merge often just stops and goes nowhere: it sits in a polling loop on CI, or hits
a manual merge gate and waits. Two cures, in order of preference.

## 1. Delegate the wait to the platform (native auto-merge) — preferred

Instead of polling CI and babysitting, set the PR/MR to auto-merge and **move on to another task**.
The platform merges once checks pass and review is approved:

- GitHub: `gh pr merge <PR> --auto --squash` (needs repo auto-merge enabled + branch protection).
- GitLab: `glab mr merge <IID> --when-pipeline-succeeds` (respects merge train if enabled).

This removes the wait entirely — the agent does not hang on green-CI. **Whether it is allowed is a
project-policy decision (below).**

## 2. If you must wait — wait non-blocking

Never block the session (see [[github-ops]] Anti-hang). Poll one `gh pr view --json
statusCheckRollup,reviewDecision,mergeable,mergeStateStatus,isDraft,state` → classify → `ScheduleWakeup`
(cache-window discipline: ≤270s or ≥600s, avoid 280–550s). Cap consecutive no-change polls and surface
a blocker rather than looping forever.

## Project-differentiated policy — read it from the project, don't hardcode

Autonomy is **not** uniform across repos. Read the policy from the project layer (`<repo>/CLAUDE.md`
"PR/MR policy" section); when absent, infer from the profile below and state the assumption.

| | Personal GitHub (loose) | Team GitLab / shared repo (cautious) |
|---|---|---|
| Native auto-merge | allowed by default | **only with explicit consent** — silent MWPS/merge-train can stall the team's queue/pipeline |
| `--auto` round gate | on by default | off — keep manual review of each round |
| Manual merge gate | may be relaxed | **mandatory** |
| Pre-push checks | light | run full local `/check` before every push |
| `--force-with-lease` | fine | careful — it dismisses others' approvals; re-request review after |
| Parallelism | aggressive | conservative; respect merge queue / others' work |

Default for any non-personal / unknown-ownership repo: **cautious**. When unsure which profile applies,
ask once, then record the answer in the repo's `CLAUDE.md`.

## Offer autonomy early

When setup detects a long wait ahead (CI ≥ 5 min, or review pending), proactively offer the autonomous
path — "set auto-merge and switch to another task?" — instead of silently stalling. Don't make the user
remember to pass `--auto`.

## Parallel work across several PRs

- One worktree per PR (`Agent(isolation: worktree)`) — parallel fixes without disk conflicts.
- For long cross-session babysitting of many PRs, use `/schedule` (cron routine): "every N min — advance
  ready PRs, fix failed ones". Robust across session end.
- With native auto-merge in place, parallel babysitting is mostly unnecessary — the platform finishes
  each PR on its own.
