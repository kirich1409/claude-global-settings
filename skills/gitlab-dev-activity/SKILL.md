---
name: gitlab-dev-activity
description: |
  Collect and report a GitLab developer's activity for a given period. Use this skill whenever the user asks to analyze, evaluate, or compare a developer's contribution, activity, or performance in GitLab — e.g. "how active is @username", "show stats for X", "compare X with Y", "what did X do this month", "analyze developer activity", "team member performance report", "how many MRs did X review", "evaluate X's work over the last N months". Auto-detects the project from git remote. Default period: 90 days.
---

# GitLab Developer Activity Report

Produces a comprehensive activity report for one or two GitLab developers.

## Inputs (extract from user request)

- `username` — GitLab username (required)
- `compare_username` — second username for side-by-side comparison (optional)
- `period_days` — lookback period in days (default: **90**)
- Project — **auto-detected** from `git remote get-url origin`

## How to run

The skill bundles a ready-made script at:
```
$HOME/.claude/skills/gitlab-dev-activity/scripts/analyze.py
```

Run it from the project's git directory (project is auto-detected from git remote):

```bash
# Single user, default 90 days
python3 "$HOME/.claude/skills/gitlab-dev-activity/scripts/analyze.py" \
  --username USERNAME

# Custom period
python3 "$HOME/.claude/skills/gitlab-dev-activity/scripts/analyze.py" \
  --username USERNAME --days 180

# Side-by-side comparison
python3 "$HOME/.claude/skills/gitlab-dev-activity/scripts/analyze.py" \
  --username USERNAME --compare OTHER_USERNAME

# Raw JSON output (for further processing)
python3 "$HOME/.claude/skills/gitlab-dev-activity/scripts/analyze.py" \
  --username USERNAME --json
```

The script prints a markdown report to **stdout**. Progress messages go to stderr.

## What the script collects

All data is fetched via `glab` CLI (auto-auth) and `git log`. Pagination is handled automatically.

| Source | Metrics |
|---|---|
| GitLab events API | Total events, by action, by month |
| GitLab events (action=approved) | Approvals total, monthly, IID set |
| GitLab events (action=commented) | Comment IID set (for ghost rate) |
| GitLab MRs as reviewer | Total, by state, ghost rate |
| MR notes sample (10 MRs) | How many contain real user comments |
| GitLab MRs as author | Total, states, avg/median lifetime to merge |
| GitLab pipelines | Total, by status, success rate |
| git log --oneline | Commit count, monthly breakdown |
| git log --numstat | Lines added/deleted, files changed |
| git log --format='%aI' | Work-hour distribution, weekday/weekend |

## Key metrics explained

### Ghost reviewer rate
An MR where the user was assigned as reviewer but left **no trace** — neither approved nor commented. Even one comment counts as active engagement.

```
ghost = reviewer_iids - approved_iids - commented_iids
ghost_rate = len(ghost) / len(reviewer_iids) × 100
```

### Off-hours / weekend commits
- **Off-hours**: weekday commits before 09:00 or after 18:00 (local time from git)
- **Weekend**: Saturday or Sunday commits

High off-hours % can mean extra effort or irregular schedule — always compare with team norms and check for known vacations/team pauses in the same period.

### Inactive months
Months where both GitLab events = 0 AND git commits = 0. The report flags these and reminds to check whether the whole team was quiet then (holiday, sprint break, etc.).

## Report structure

The script outputs (in Russian):

1. **Сводка** — key numbers table
2. **Код** — commits, lines, MRs as author, monthly commit table
3. **Review-активность** — ghost rate, approvals, time-to-approve, comment quality
4. **Активность по месяцам** — events / approvals / commits side by side
5. **Рабочий ритм** — commits by weekday, off-hours and weekend counts
6. **Пайплайны** — success/fail rates (if data available)
7. **Периоды без активности** — inactive months with context note
8. **Сигналы** — automatic 🔴🟡🟢⏰⚪ flags based on thresholds

In comparison mode (`--compare`): adds a side-by-side summary table and merged signals section before the individual reports.

## Signals reference

| Signal | Condition |
|---|---|
| 🔴 Ghost rate > 70% | Assigned reviewer, mostly absent |
| 🔴 Ghost rate > 40% | Significant share of assignments ignored |
| 🔴 Approval rate < 20% | Approves only a tiny fraction |
| 🔴 0 comments | No review feedback left |
| 🔴 < 3 commits | Minimal code contribution |
| 🟡 Ghost rate 20–40% | Some MRs skipped, majority covered |
| 🟡 Time-to-approve > 3 days | Slow review response |
| 🟢 Ghost rate < 20% | Responds to nearly all reviewer assignments |
| 🟢 Time-to-approve < 1 day | Fast review response |
| 🟢 Approval rate > 50% | High review engagement |
| ⏰ Weekend commits | Work on Sat/Sun |
| ⏰ Off-hours commits | Work before 09:00 or after 18:00 |
| ⚪ Inactive months | Zero activity for a full calendar month |

## Data limitations

- GitLab events API retention: typically 3–6 months depending on server config. If totals seem low, note it.
- Git stats cover only **this repository**. Cross-project contributions won't appear.
- Pipeline data is limited to the first 100 pipelines (usually sufficient for 90-day windows).
- Work-hour analysis uses UTC from git commit timestamps; may differ from developer's local timezone.
