---
name: worktree-cleanup
description: >-
  Scan the current repo for stale git worktrees and local branches, classify them
  (merged / remote-gone / stale agent worktrees / still-active), and remove the safe ones
  after a single user confirmation. Enforces the disk-economy policy from
  rules/git-workflow.md: unused worktrees are not kept "just in case".

  Use when: "clean up worktrees", "убери worktrees", "почисти ветки", "disk space",
  "stale branches", "worktree cleanup", after a PR merge when the worktree is no longer
  needed, or at end-of-session when several worktrees look finished. Do NOT use to delete
  a worktree with uncommitted changes or unpushed commits — those are surfaced, never removed.
---

# Worktree cleanup

Goal: bring the repo back to "no idle worktrees" (disk-economy policy, `rules/git-workflow.md`).
Deletion is destructive — classify first, confirm once with the full list, then remove.

## Step 1 — gather (read-only)

```bash
git fetch --prune
git worktree list --porcelain
git branch -vv          # gone-markers + upstream state
git branch --merged origin/main
```

For each worktree (skip the main checkout) also check:

```bash
git -C <wt> status --porcelain     # uncommitted changes?
git -C <wt> log --oneline @{u}.. 2>/dev/null   # unpushed commits?
```

## Step 2 — classify

| Class | Criteria | Action |
|---|---|---|
| **Safe to remove** | branch merged into `origin/main`, or remote-tracking branch `gone`; worktree clean; no unpushed commits | propose removal |
| **Stale agent worktree** | `worktree-agent-*` / auto-generated name; clean; branch has no open PR | propose removal |
| **Locked** | `git worktree list` shows `locked` | skip, mention with lock reason |
| **Active** | uncommitted changes, unpushed commits, or open non-draft PR awaiting review rounds | keep, list as "in use" |

Open-PR check: `gh pr list --head <branch> --state open` (or `glab` on GitLab remotes).

## Step 3 — confirm once, then remove

Present ONE table: path, branch, class, evidence (merged PR #N / gone / clean). Ask a single
yes/no (optionally per-row exclusions). Never delete without this confirmation.

On confirmation, per worktree:

```bash
git worktree remove <path>          # --force only if user explicitly approved a dirty removal
git branch -D <branch>              # only when merged or remote is gone
git push origin --delete <branch>   # only for merged branches whose remote lingers
```

Finish with `git worktree prune` and report freed paths. Branches are cheap to recreate
from remote — "might need it later" is not a reason to keep (policy).

## Guardrails

- Never touch the main checkout or the current session's own worktree.
- Never delete locked worktrees; report the holder instead.
- Uncommitted/unpushed → surface loudly, never remove, never stash silently.
- This skill deletes local state only; closing PRs or issues is out of scope.
