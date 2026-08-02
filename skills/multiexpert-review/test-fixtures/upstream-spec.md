---
type: spec
slug: smoke-test-upstream-fixture
status: approved
---

# Spec: Background SMS auto-import (upstream-defect fixture)

Synthetic fixture for the upstream detector; the paired fixture `upstream-plan.md` links to this file
via `spec:`. What exactly is defective here and how it must be classified is stated in `SMOKE_TEST.md`
only — never in this file, which is fed to reviewers verbatim.

## Context and Motivation

The app should fill in one-time codes for the user without them leaving the screen.

## Acceptance Criteria

- [ ] **AC-1** — On Android 14, the app reads the full SMS inbox in the background, with no runtime
      permission prompt and without being the default SMS handler. `[agent]`
- [ ] **AC-2** — Every OTP is auto-filled within 200 ms of the SMS arriving. `[user]`
- [ ] **AC-3** — The app never accesses message content without an explicit user action. `[user]`

## Technical Constraints

- No new dependencies.
- Minimum supported platform: Android 14.

## Decisions Made

| Decision | Choice | Rationale | Source |
|---|---|---|---|
| How OTP is obtained | Read the inbox directly | Fewest moving parts | agent |

## Out of Scope

Anything not related to OTP entry.
