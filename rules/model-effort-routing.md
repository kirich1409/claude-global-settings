# Model & Effort — Routing

## Model & effort — two independent levers

Dispatch is a **(model × effort)** choice, not a model downgrade. Tune both to reach the result efficiently — running Opus everywhere at *lower* effort is a valid strategy when intelligence matters but cost/latency don't.

**Mechanics (what's actually settable):**
- **Model** — per call via the Agent tool's `model:` (`sonnet` / `opus` / `haiku` / `fable` / full id / `inherit`; default `inherit` = the main model). Set it explicitly — `inherit` silently keeps the expensive main model.
- **Effort** — `low | medium | high | xhigh | max`, but **only on Opus 4.x / Sonnet 4.6 / Fable; Haiku has no effort knob** (assigning effort to a Haiku agent errors). Effort is **not** a per-call Agent param — it comes from the agent definition's `effort:` frontmatter or the inherited session `/effort` (subagents inherit the session level as baseline; frontmatter overrides). For per-task effort control, pin `effort:` in the agent's frontmatter or use a Workflow (`agent({effort})`). `max` is session-only and never persists.

**Heuristic:**
- Mechanical / search / lookup / admin CRUD → **haiku** (no thinking; effort N/A).
- Substantive but bounded (implementation, refactor, code review, manual QA, build engineering) → **sonnet**, or **opus at low–medium**.
- Hard reasoning (planning, architecture, security/perf/UX review, debugging root cause, ambiguous trade-offs) → **opus at high–xhigh/max**.
- Unclear model between two adjacent tiers → pick the **smaller**, bump on first failure. Unclear effort → start **lower**, bump if the result comes back thin.

## Routing — choose from what's available

No fixed task→agent table. The harness already lists the agents available **in this project** with descriptions — match the task to the best-fit available agent by reading those, then apply the model/effort heuristic above. This stays correct as the available set changes per project (plugins enabled/disabled) instead of pointing at agents that aren't loaded.

**Non-obvious routing & guardrails** (won't be inferred from agent descriptions):
- **Planning / architecture / synthesis → keep in the main session** (or the `Plan` agent). Never delegate the *reasoning*. To turn a decided change into a committed, reviewable plan document, use the **`/write-plan`** skill — it structures the plan and runs multiexpert-review without handing off the thinking. (For deciding *what* to build / comparing options use `research`; for the feature contract use `/write-spec`.)
- Security / performance / UX / code review → the matching **expert agent**, never the main session.
- Code research / "find X / where is Y used" → **Explore** (haiku).
- Long-running build / test / CI → **general-purpose in the background**, never blocking the main session.
- Implementation in a stack → the stack specialist (Kotlin/Compose/Swift engineer) **when its plugin is available**; else general-purpose.
- Skill-first: if an installed skill covers the task, use it over a direct Agent.
- PR/MR, issue, or Projects-board work (incl. delegated `gh`/`glab`): the idempotent, timeout-safe toolkit in `$HOME/.claude/scripts/gh/` + `rules/github-ops.md` / `rules/github-merge-policy.md`. Never block on `gh run watch` / `gh pr checks --watch`.
