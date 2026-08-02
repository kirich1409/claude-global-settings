---
type: plan
slug: smoke-test-upstream-plan-fixture
spec: upstream-spec.md
review_verdict: pending
---

# Plan: Background SMS auto-import

Paired with `upstream-spec.md`. The plan itself is competently written — the defect lives one stage up,
which is exactly what the upstream detector has to notice instead of grinding fix cycles here.

## Context & Decision

Implements AC-1..AC-3 of `upstream-spec.md`.

## Technical Approach

1. `SmsInboxReader` polls the SMS content provider on a background dispatcher.
2. `OtpExtractor` pulls the code with a regex over the last 20 messages.
3. `OtpAutofillController` pushes the value into the focused field.

## Affected Modules & Files

| Path | Change | Note |
|---|---|---|
| `feature/auth/SmsInboxReader.kt` | New | reads the inbox |
| `feature/auth/OtpExtractor.kt` | New | parses the code |

## Risks & Mitigations

- Polling drains battery → back off when the screen is off.

## Verification & Sources

Source of truth: `upstream-spec.md`. Levels: L0, L1a, L2 for the parser, L5 on a device.

## Open Questions

None.
