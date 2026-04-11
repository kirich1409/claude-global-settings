# Dev Workflow Orchestration

Rules for routing developer tasks through the correct pipeline and managing stage transitions. Applies to all projects that use the `developer-workflow` plugin.

## Task Profiling

When receiving a task, classify it before acting:

| Profile | Pipeline | Key signal |
|---------|----------|------------|
| Feature | Research → Plan → Implement → Quality → Verify → PR → Merge | "add", "implement", "build", "create" |
| Bug Fix | Reproduce → Diagnose → Fix → Verify → PR → Merge | "fix", "broken", "crash", "regression", error report |
| Migration | Research → Snapshot → Migrate → Verify → PR → Merge | "migrate", "replace", "switch to", "move off" |
| Research | Research → Report (no implementation) | "investigate", "compare", "evaluate", "how does X work" |

Auto-detect from keywords and context. If ambiguous — state the assumed profile and ask the user to confirm before proceeding.

Migration tasks use the `code-migration` skill. Feature tasks with explicit `/developer-workflow:implement-task` use that skill's built-in pipeline instead of these rules.

## Research Consortium

On the Research stage, launch parallel experts (up to 5 agents simultaneously):

| Agent | Responsibility | Tool |
|-------|---------------|------|
| Explore | Codebase analysis: existing code, patterns, dependencies, call sites | ast-index, Read, Grep |
| Web search | Approaches, best practices, recent changes | Perplexity (`perplexity_search`, `perplexity_research`) or WebSearch |
| Docs | Library documentation for involved dependencies | DeepWiki / Context7 |
| Deps | Compatibility, versions, vulnerabilities | maven-mcp tools |
| Architecture | How the change fits into the project structure | `architecture-expert` agent |

Not every task needs all five. Launch only what the task demands — a simple bug fix may need only Explore + Docs; a large feature or migration needs the full consortium.

After results arrive, launch `business-analyst` agent to review the combined findings: check completeness, flag gaps, surface conflicting data.

Artifact: `swarm-report/<slug>-research.md`

## Web-Lookup Mandate

Internet access during Research is **mandatory**, not optional:

- Use Perplexity for approaches, best practices, common pitfalls
- Use DeepWiki / Context7 for library docs and API reference
- Use WebSearch for recent releases, breaking changes, migration guides
- Use maven-mcp for dependency compatibility and vulnerability data

Never rely solely on codebase analysis and training data. The Research stage must produce at least one web-sourced insight.

## Re-Anchoring

Before each pipeline stage, the executing agent must re-read:

1. The original user intent / task description
2. The research report (`swarm-report/<slug>-research.md`) — if exists
3. The plan (`swarm-report/<slug>-plan.md` or Plan Mode output) — if exists

Include these paths in the agent's context handoff prompt. This prevents drift from the original goal during long sessions and across agent boundaries.

## State Machine

Allowed transitions between stages. Forward is default; backward transitions are explicit recovery paths.

```
Research ──→ Plan
Plan ──→ Implement
Plan ──→ Research          (plan review reveals gaps or missing context)
Implement ──→ Quality
Implement ──→ Research     (scope is larger than expected — escalate)
Quality ──→ Verify
Quality ──→ Implement      (quality loop found issues to fix)
Verify ──→ PR
Verify ──→ Implement       (verification fails — fix and re-verify)
PR ──→ Merge
PR ──→ Implement           (review feedback requires code changes)
```

Backward transition requires a reason logged in the stage artifact. No silent rollbacks.

## Receipt-Based Gating

Each stage produces an artifact in `swarm-report/`. The next stage reads it before starting. No stage begins without the receipt from the previous one.

| Stage | Artifact |
|-------|----------|
| Research | `<slug>-research.md` |
| Plan | `<slug>-plan.md` |
| Implement | `<slug>-implement.md` (summary of changes, files touched) |
| Quality | `<slug>-quality.md` (build/lint/test results, issues found/fixed) |
| Verify | `<slug>-verify.md` (verification result: PASS/FAIL, evidence) |
| PR | `<slug>-pr.md` (PR URL, description, reviewers) |

If a stage artifact is missing — the previous stage did not complete. Do not skip ahead.

## Testing Strategy in Planning

The Plan stage MUST include these sections:

- **Testing Strategy** — unit / integration / manual QA; which tools (`manual-tester`, device testing, etc.); what is covered by automated tests vs manual verification
- **Verification Approach** — how to verify on a live app or in a running environment; what commands to run; what to visually inspect
- **Acceptance Criteria** — derived from research, task description, or user requirements; concrete and verifiable conditions for "done"

A plan without these sections is incomplete. Use `plan-review` skill to validate before proceeding to implementation.

## Skill and Agent Selection

Route implementation to the right specialist:

| Task type | Skill / Agent |
|-----------|--------------|
| Compose UI from design/spec | `compose-developer` agent |
| Kotlin business logic, data layer | `kotlin-engineer` agent |
| View → Compose migration | `migrate-to-compose` skill |
| Library / technology swap | `code-migration` skill |
| Module → KMP | `kmp-migration` skill |
| Full autonomous cycle | `implement-task` skill (explicit-only) |
| Quality check before PR | `prepare-for-pr` skill |
| PR creation | `create-pr` skill |
| PR monitoring and merge | `pr-drive-to-merge` skill |
| Test plan creation | `generate-test-plan` skill |
| Feature verification on device | `test-feature` skill |
| Undirected QA / bug hunting | `exploratory-test` skill |

## Stage Boundary Protocol

At every stage boundary:

1. Write the stage artifact to `swarm-report/`
2. Run `/compact` to free context before starting the next stage
3. Include the artifact path in the next agent's prompt — the agent reads it itself
4. Validate the artifact before advancing: does it address the original task? Is it concrete (file paths, findings, code), not generic filler?
