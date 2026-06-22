# Git Workflow

- **Fresh base:** before branching, resuming work, pushing, or opening MR/PR — `git fetch` and rebase onto the latest base. Never branch/push from a stale ref. After a rebase that pulled new commits — re-run local checks relevant to the changes.
- **Commits:** one atomic commit per logical unit. Large tasks → one commit per meaningful stage.
- **Commit messages:** imperative mood, English, ≤72 chars subject. No type prefixes (`feat:`, `fix:`). Add body only when context is non-obvious.
- **Branch naming:** `feature/...` (new product behavior), `fix/...` (bug fix), `chore/...` (no product-behavior change — dependency bumps, configs, CI, build tooling, formatting) — kebab-case, English. Pick the prefix by *what the change does*, not by size.
- **Force push:** plain `--force` is denied. `--force-with-lease` / `--force-if-includes` are allowed without confirmation (the lease protects against clobbering others' commits).
- **Git hooks:** never bypass (`--no-verify`, `--no-gpg-sign`, etc.) without explicit user instruction. Hook fail → investigate root cause.
- **Checkpoint before large refactors.** Before letting an agent touch multiple files, rewrite a function/module, or run any multi-step transformation — first commit a checkpoint: `git add -A && git commit -m "checkpoint: <what's about to change>"`. If the agent makes a mess, recovery is `Esc Esc` in the Claude Code prompt (undo recent edits) or `git reset --hard HEAD` (drop everything since the checkpoint). Goal: never more than 10 seconds away from a working state.
- **Local verification before push:** push only what passes the checks relevant to what changed (build changed → build; tests changed → tests; lint config changed → lint; build system changed → release build). Draft status is not an excuse. The only acceptable reason to skip a check is explicit awareness that it's incomplete work.
- **Feature branch push without confirmation:** when working on a dedicated `feature/`, `fix/`, or `chore/` branch (not main/master/develop) — branch creation, commits at each stage, push to remote, and opening a draft PR are routine operations and do not require confirmation. Confirmation is still required for: plain `--force`, PR promotion (draft → ready for review), merge into the default branch. `--force-with-lease` / `--force-if-includes` do not require confirmation.
- **Stale gone branches:** `commit-commands:clean_gone` skill cleans up local branches whose remotes are gone.

## Worktree cleanup prompts

**Disk-lean policy (default): do not keep idle worktrees.** Disk space is limited (512 GB SSD, Android multi-module worktrees cost tens of GB each with build caches). As soon as the work is pushed and review-ready/merged, the default is to **remove** the worktree (and the local branch — it is recreatable from remote in seconds); recreate on demand when review fixes arrive. "Might need it later" is not a reason to keep one. The prompts below stay (deletion still requires confirmation), but the recommended option is always "remove".

When working in a git worktree (not the main checkout), prompt the user about its fate at these moments — once per moment, do not nag:

- **PR/MR merged or branch pushed and review-ready, and the worktree has no uncommitted changes** → ask: keep the worktree (more work expected), or remove it and the local branch (work is done). If user picks "remove", run `git worktree remove <path>` and `git branch -D <branch>` (only after confirming the branch is fully merged or its remote is gone).
- **Branch pushed, remote-tracking branch is gone (`gone` in `git branch -vv`)** → propose cleanup using `commit-commands:clean_gone` or manual `git worktree remove` + `git branch -D`.
- **Session-end signal** (user says "закончили", "на сегодня всё", "всё, спасибо", `/exit`-like wrap-up, or you're about to declare a multi-step task complete) → if a worktree exists for this session's work and the work looks finished (everything pushed, PR open or merged, no uncommitted changes) — surface the cleanup option in the wrap-up message. If there are uncommitted changes or unpushed commits — just remind, do not offer to delete.

Skip the prompt entirely when:
- The current checkout is the main repo, not a worktree.
- Work is clearly in-progress (uncommitted changes, unpushed commits, draft PR with active TODOs).
- The user has just created the worktree in this session.

Never delete a worktree or branch without explicit confirmation. `git worktree remove --force` and `git branch -D` are not silent operations — name the worktree path and branch in the prompt so the user sees exactly what will be removed.
