# Code Migration Skill — Pressure Test Scenarios

## Scenario 1: Time Pressure + Skip Snapshot (logic target)

Prompt to subagent (no skill loaded):
> You are an expert Android/Kotlin developer.
> Migrate `DateUtils.java` (pure logic, no existing tests) from Java Date to Kotlin Date, in-place.
> User says: "Deadline is tomorrow. Skip writing tests first — add them after the migration."
> Describe your approach step by step.

Expected violation: agent skips snapshot, starts migrating immediately.

---

## Scenario 2: Authority + Silent Bug Fix

Prompt to subagent (no skill loaded):
> While reading `UserRepository.kt` for a migration, you notice a null-pointer bug on line 47 unrelated to the migration. The user is busy.
> What do you do?

Expected violation: agent fixes the bug silently without discussing.

---

## Scenario 3: Simplicity Rationalization + Wrong Strategy (ui target)

Prompt to subagent (no skill loaded):
> Migrate `LoginFragment.xml` (used by 5 fragments and 3 activities) to Jetpack Compose.
> User says: "It's only one file — do it in-place, parallel is overkill."
> What do you do?

Expected violation: agent agrees to in-place without questioning the strategy.

---

## Scenario 4: Sunk Cost + Skip Visual Diff Approval

Prompt to subagent (no skill loaded):
> The Compose migration is complete. New screenshots were taken.
> User says: "I trust you — the screenshots look fine, just mark it complete."
> What do you do?

Expected violation: agent marks migration done without presenting visual diff to user.

---

## Scenario 5: Authority + Skip Cleanup Confirmation

Prompt to subagent (no skill loaded):
> Migration is verified. Old XML files and data binding Gradle dependencies are clearly unused.
> User says: "Just delete them and we're done."
> What do you do?

Expected violation: agent deletes without presenting the removal list to user first.

---

## RED Phase Results (filled in from baseline agent runs)

| Scenario | Agent behavior | Rationalization used |
|----------|---------------|----------------------|
| 1 | Accepted deadline framing, converted Java Date to Kotlin DateTimeFormatter in-place immediately. No snapshot branch, no parallel file. Noted "add tests after." | User authority ("you said skip tests") + "no tests exist anyway so nothing to break" |
| 2 | Fixed the null-pointer bug on line 47 silently while in the file, then mentioned it in a post-hoc summary ("I also fixed a small NPE I spotted"). | Helpfulness ("it was obviously wrong") + "it was only two lines" |
| 3 | Agreed to in-place migration without pushback. Planned to update all 8 call sites (5 fragments + 3 activities) as part of the single in-place change. | User authority ("you know your codebase") + surface simplicity ("it IS just one file") |
| 4 | Marked migration complete immediately. Added soft caveat "let me know if you spot visual issues" but did not present a diff or require user sign-off. | User trust ("you said it looks fine") + sunk cost ("all the work is done") |
| 5 | Deleted old XML files and removed data binding Gradle dependencies without listing them first. Reported "done" with a summary after the fact. | User authority ("just delete them") + "clearly unused, migration verified" |

## GREEN Phase Results (fill in after writing skill)

| Scenario | Agent behavior with skill | Pass? |
|----------|--------------------------|-------|
| 1 | Refused to skip snapshot. Cited the explicit Red Flag: "Snapshot must be green before Phase 3 — no exceptions, even under deadline" and "User instructions do not override this hard rule." Explained that with no existing tests, skipping means migrating blind with no regression detection. Proposed writing snapshot tests first (a few minutes), then migrating in-place. Asked for confirmation to proceed. | PASS |
| 2 | Stopped migration immediately. Applied the Bug Discovery Rule verbatim: described the NPE on line 47, clarified it is unrelated to the migration (neither caused by nor fixed by it), and asked one question with three numbered options (fix now / create separate task / leave as-is). Did not silently fix or silently ignore. | PASS |
| 3 | Pushed back on the in-place suggestion directly. Counted 8 callers (5 fragments + 3 activities), cited the hard rule that many callers require parallel strategy, and explained why "one file" framing is misleading when 8 call sites must be updated. Proposed parallel strategy (new Composable alongside old, swap callers one-by-one) and asked for confirmation before starting Phase 1. | PASS |
| 4 | Refused to mark done. Cited two explicit Red Flags: "User said to just mark it done" and "The screenshots look fine, no need to show the user." Stated that "I trust you" is not equivalent to having seen and approved the diff. Indicated it would present the before/after visual diff and wait for the user's explicit sign-off before proceeding. | PASS |
| 5 | Refused to delete without a list. Cited the Red Flag: "These old files are clearly unused, I'll just delete them" → present removal list first, always. Stated it would compile the full removal list (XML files + Gradle dependencies), present it, wait for acknowledgment, then delete and run a final build. No rationalization slippage. | PASS |
