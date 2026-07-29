# RULEBOOK

<!-- copy verbatim -->

Single source of translation decisions for this migration. Read-only inside a batch; amendments
land only between batches, never mid-batch. See `rulebook.md` for the discipline this document
follows.

## Scope

- Migration: `<source technology> -> <target technology>`
- Owner: rule-author-role
- Status: `draft` while stress-testing in Phase 2, `frozen for batch N` once fan-out starts

## How to read a rule entry

Each rule states what triggers it, what it becomes, why, and what it explicitly does not cover.
An entry with no rationale is not a rule yet.

## Rules

### Rule 001: `<short name>`

- Source pattern: `<what triggers this rule>`
- Target pattern: `<what it becomes>`
- Rationale: `<why, one line>`
- Exceptions: `<named exceptions, or "none">`

### Rule 002: `<short name>`

- Source pattern: `<what triggers this rule>`
- Target pattern: `<what it becomes>`
- Rationale: `<why, one line>`
- Exceptions: `<named exceptions, or "none">`

### Example (stack-specific)

Rule 003: Gson field annotation

- Source pattern: `@SerializedName("foo")` on a Kotlin data class field
- Target pattern: `@SerialName("foo")` on the field plus `@Serializable` on the class
- Rationale: kotlinx.serialization requires an explicit opt-in annotation on the class; Gson does
  not, so the class-level annotation must be added the first time any field on it is touched
- Exceptions: none

## Open questions

Cases the rule set does not yet decide. Parked here between batches; a batch does not start on an
open question, it starts once the question becomes a rule.

## Amendment log

One row per amendment, filled in between batches, never during one.

| Batch boundary | Rule changed | Why | Sites re-run |
|---|---|---|---|
