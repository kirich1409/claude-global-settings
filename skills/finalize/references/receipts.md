Referenced from: `~/.claude/skills/finalize/SKILL.md` (§Report).

# Finalize — Report Templates and Chat Summaries

Full templates for the two artifacts finalize writes on exit (`<slug>-finalize.md` detail
log, `<slug>-quality.md` terse receipt) and the chat-summary formats for PASS / ESCALATE.
SKILL.md keeps the instruction to save these on exit; this file holds the schemas.

## Detailed report — `swarm-report/<slug>-finalize.md`

Save on exit (PASS or ESCALATE):

```markdown
# Finalize: <slug>

**Date:** <date>
**Rounds run:** N (of 3 max)
**Exit:** PASS | ESCALATE
**Escalation reason:** <only if ESCALATE>

## Rounds

### Round 1
- Phase 0 (deep scan /code-review): `effort=<tier> — reason: <signal>`, N findings after dedup vs Phase A (or `skipped: trivial diff | --skip-deep-scan | bound marketplace shadow`).
- Phase A (code-reviewer): verdict, N findings (K BLOCK, M WARN, L NIT). Fixes: X.
- Phase B (/simplify): Y files changed, auto-fixed.
- Phase C (pr-review-toolkit): per-agent breakdown, or `skipped` if plugin not installed.
- Phase D (experts): triggered: [security-expert, ...]; findings, fixes.
- `/check` after round: PASS | FAIL (reason)

### Round 2 ...

## Unresolved BLOCKs (ESCALATE only)
Findings that could not be fixed and were NOT downgraded — populated only on ESCALATE; lists BLOCKs after `max_rounds` rounds OR BLOCKs whose fix broke `/check` and was reverted. User decides: return to implementation, accept as risk, or re-scope.

| Severity | Confidence | Category | Finding | Phase | Round | File:Line |
|---|---|---|---|---|---|---|
| BLOCK (critical) | 75 | security | Token logged in clear | D | 3 | src/auth/Logger.kt:23 |

## Remaining findings (not auto-fixed)
Non-BLOCK items for reviewer awareness — never block PASS.

| Severity | Confidence | Category | Finding | Phase | File:Line |
|---|---|---|---|---|---|
| WARN | 60 | quality | Inconsistent error logging | A | src/foo/Bar.kt:142 |
| NIT  | 75 | consistency | Unused import in new file | B | ... |

## Acknowledged risks
Findings the user explicitly decided to accept (e.g. at escalation). Not auto-populated — distinct from "Unresolved BLOCKs".

## Commits added during finalize
- <hash> <message>
```

## Quality receipt (terse) — `swarm-report/<slug>-quality.md`

Also save on the same exit (PASS or ESCALATE). This is the terse receipt consumed by downstream skills (`acceptance` Step 2.5 dedup probe and `create-pr`'s status table) — the detailed `<slug>-finalize.md` above is the round-by-round log, this is the one-glance gate result.

```markdown
# Quality receipt: <slug>

Status: PASS | FAIL
Date: <date>
Escalate: <true — only on ESCALATE; omit otherwise>
Detail: swarm-report/<slug>-finalize.md
```

Verdict mapping: `Exit: PASS` → `Status: PASS`; `Exit: ESCALATE` → `Status: FAIL` plus `Escalate: true`. `Date:` is mandatory — `acceptance` Step 2.5 infers freshness from `Date:` against the branch commit window; if it cannot confirm, it does NOT skip `code-reviewer`, so `Date:` alone is sufficient and no commit SHA is needed.

## Chat summary on exit (≤20 lines)

**PASS:** "Finalize: PASS after N round(s). Code is ready for acceptance." Bullets — N findings fixed by category (security X, quality Y, style Z); if 0, state so. Next step: `/acceptance`.

**ESCALATE:** "Finalize: ESCALATE after N round(s). X unresolved BLOCK(s) require decision." Bullets (max 5, top by severity): one BLOCK per bullet with category + one-line description. ONE question: which BLOCK first, or pick accept-risk / continue-implementing / re-scope. Options — proceed to `/acceptance` accepting risks, or return to implementation with a new task.
