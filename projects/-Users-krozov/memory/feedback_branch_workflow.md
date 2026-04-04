---
name: Branch and worktree workflow
description: User always works in separate branches/worktrees per task. Confirm branch before making changes to prevent mixing tasks.
type: feedback
---

Always work in a separate branch and worktree per task. Never start editing without confirming the current branch is correct for the task at hand.

**Why:** User has been burned by accidentally doing work in the wrong branch and mixing different tasks together.

**How to apply:** At the start of any conversation involving code changes, check `git branch --show-current` and confirm with the user that this is the intended branch for the current task. If on main/master or a branch that doesn't match the described task, warn immediately and suggest creating a new branch or switching to the correct one.
