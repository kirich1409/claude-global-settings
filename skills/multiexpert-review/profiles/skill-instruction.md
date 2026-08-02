---
name: skill-instruction
description: Profile for Claude Code skill instructions (skills/<name>/SKILL.md plus its references/). Panel of architecture-expert + business-analyst. Rubric checks executability against real tool schemas, determinism across parameter combinations, parameter contract integrity, and downstream consumer agreement.

detect:
  frontmatter_type: [skill, skill-instruction]
  path_globs:
    - "**/skills/**/SKILL.md"
    - "**/skills/**/references/*.md"
  structural_signatures: []

reviewer_roster:
  primary: [architecture-expert, business-analyst]
  optional_if:
    - when: "AskUserQuestion|вопрос|диалог|интерактив|раунд"
      agent: ux-expert
    - when: "параллельн|консорциум|бюджет|токен|subagent|субагент"
      agent: performance-expert
    - when: "secret|token|credential|permission|deny|allow-list"
      agent: security-expert

allow_single_reviewer: false

verdicts: [PASS, CONDITIONAL, FAIL]

severity_mapping:
  - items: [executability, determinism]
    severity: critical
  - items: [parameter_contract, downstream_contract, invariants]
    severity: major
  - items: [scope_boundaries, progressive_disclosure, redundancy]
    severity: minor

source_routing:
  plan_mode: N/A
  file: edit-in-place
  conversation: inline-revise
---

## Rubric

Разделы `## Rubric` и `## Prompt augmentation` остаются английскими: они уходят рецензентам дословно
как дополнение промпта.

Reviewers evaluate a skill instruction — the document an agent executes step by step — against these
criteria. Each bullet carries the **item ID** in parentheses; use the ID verbatim at the start of every
Issue title so synthesis and greps stay traceable.

The artifact is not a plan and not a spec: nobody implements it, an agent *runs* it. Judge it as
executable instructions, and remember its reader is a model with no memory of this conversation.

### Critical — the skill misbehaves at runtime without these

- **(executability) Every instruction is performable with the tools the runtime actually offers** — a
  step that prescribes an impossible call (more options than a tool's schema allows, a field that does
  not exist, dialogue from a context where dialogue cannot reach the user) fails silently at runtime.
  Verify prescriptions against real schemas and real agent definitions, not against plausibility.
- **(determinism) Every branch resolves to exactly one behaviour** — walk the combinations: each flag
  alone, flags together, each flag with the conditions that skip a phase, the empty and single-element
  results of any discovery step. A combination the text does not resolve is a defect, even when each
  rule reads fine alone. Two rules that both apply and disagree is the same defect.

### Major — the skill runs but produces wrong or unusable output

- **(parameter_contract) The parameter surface is coherent** — `argument-hint` matches the argument
  table and the phase text; every parameter has a stated consequence; no parameter is described in prose
  that the interface does not declare, and none is declared without a described effect.
- **(downstream_contract) Contracts with consumers hold** — artifact paths, file names, frontmatter
  fields and hand-off formats match what downstream skills and agents expect. Check the actual consumers,
  do not assume.
- **(invariants) Stated invariants are actually protected** — where the skill names an invariant (agent
  isolation, no synthesis by collectors, no silent defaults), the instructions must not contain a step
  that quietly breaks it, and the text should say what would break it.

### Minor — the skill works but costs more than it should

- **(scope_boundaries) Non-applicability is explicit** — the skill says what it is *not* for and where
  to redirect, so it is not invoked for the neighbouring task.
- **(progressive_disclosure) Weight sits in the right layer** — detail that is needed rarely lives in
  `references/`, not in the always-read body; the body carries what every run needs.
- **(redundancy) No rule repeated without a new consequence** — restating a rule is fine when each
  restatement adds a fact; pure repetition costs context on every run.

## Prompt augmentation

This artifact is a skill instruction: a document a model executes, step by step, in a fresh session
with no memory of how it was written. Read it the way that model will.

Two failure modes matter more than style:

1. **Prescriptions that cannot execute.** Check them against the real mechanics — tool schemas, agent
   definitions, what a subagent can and cannot reach. If a step tells the runtime to do something the
   runtime does not support, say so with the evidence.
2. **Combinations the text does not resolve.** Enumerate parameter and condition combinations yourself,
   including the degenerate ones (nothing found, exactly one found, everything skipped). Name any
   combination whose behaviour is undefined or doubly defined.

Judge only what the instruction says, not what its author probably meant. Where the artifact spans
several files, treat inconsistency between them as a defect of the whole.
