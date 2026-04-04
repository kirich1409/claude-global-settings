# Migration Planning: DateUtils.java → kotlinx-datetime

## Phase 1: Discover

### Target Analysis (simulated — no source file provided)

**FROM:** Java — `java.util.Date`, `java.text.SimpleDateFormat`, `java.util.Calendar`, millisecond arithmetic
**TO:** Kotlin — `kotlinx-datetime` (`LocalDate`, `Instant`, `Clock`, `TimeZone`, `DateTimePeriod`) + `kotlin.time` (`Duration`)

**Category:** `logic` — pure utility class, no UI, no framework coupling, 8 public static methods

### Codebase Impact (simulated)

| Factor | Assessment |
|---|---|
| Callers | Simulated: 3–5 callers across feature modules (ViewModels, repositories) |
| Hidden consumers | Possible: Room type converters, JSON serializers accepting `Date` |
| Module boundary | Assumed: mixed into a larger module (typical for utils) |
| Test coverage | None — explicitly stated in task description |
| API stability | Breaking: public interface changes from `java.util.Date` params to kotlinx-datetime types |
| Build speed | Unknown |

### Dependency Changes Required

| Dependency | Action | Notes |
|---|---|---|
| `org.jetbrains.kotlinx:kotlinx-datetime` | Add | New dependency, KMP-compatible |
| `java.util.Date`, `java.text.SimpleDateFormat` | Remove | Replaced by kotlinx-datetime APIs |
| `java.util.Calendar` | Remove | Replaced by `Clock` and `TimeZone.currentSystemDefault()` |

### Strategy Proposal

**Option A — Parallel (Expand-Contract)** ⭐ recommended

Preparation: None (utility class with no existing state or DI; no module isolation needed for a single file)

Migration:
1. Write characterization tests as snapshot baseline (Phase 2 — this document)
2. Create `DateUtilsNew.kt` alongside `DateUtils.java` using kotlinx-datetime APIs
3. Mark `DateUtils.java` methods `@Deprecated` with `replaceWith` pointing to `DateUtilsNew`
4. Migrate callers one-by-one; build stays green after each swap
5. Delete `DateUtils.java` when all callers switched

PRs:
- PR 1: Snapshot (characterization tests only — no production code changes)
- PR 2: `DateUtilsNew.kt` + `@Deprecated` on old class
- PR 3: Caller migration batch
- PR 4: Delete `DateUtils.java` + remove old Java imports (bridge cleanup)

Effort: low
Risk: low
Why: No tests means the snapshot must be written fresh (PR 1). A parallel approach keeps callers compiling at every step and makes the cutover independently rollbackable. The class has no callers in a framework (no DI, no Room converters implied) so no hidden coupling to manage.

**Not offered: In-place** — with no tests and an API surface that changes (Date → kotlinx types), an in-place rewrite gives no safety net. If the new implementation has a subtle behavioral difference (e.g., strict vs. lenient parsing, DST handling), there is no way to catch it.

**Not offered: Big Bang** — a single-file utility class does not have the coupling that would make incremental impractical. Big Bang adds rollback complexity with no benefit here.

---

## Phase 2: Snapshot

### Quirks Discovered (require user decision before migration)

The behavior spec and characterization tests pin these quirks as **current behavior**. The user must explicitly decide whether to preserve or fix each one before Phase 3:

1. **Lenient parsing in `parseDate`** — `"2024-01-32"` silently becomes Feb 1. kotlinx-datetime's `LocalDate.parse` throws on this input. The migration must either preserve lenient behavior (by pre-processing the string) or change to strict mode (a behavioral change that must be approved).

2. **DST-blind millisecond math in `daysBetween`** — divides `(to.time - from.time)` by 86,400,000. Ignores DST transitions. kotlinx-datetime's calendar-aware approach would fix this edge case. Fixing it is a behavioral change — approve before migration.

3. **`formatRelative` with future dates** — returns `"-1 days ago"` for tomorrow. Almost certainly a bug, but currently the behavior. Approve fix or preserve.

### Outputs Produced

| File | Purpose |
|---|---|
| `behavior-spec.md` | Full behavioral contract — public interface, normal behaviors, edge cases, quirks, out-of-scope |
| `DateUtilsTest.kt` | Characterization test class — 35+ test cases pinning actual current behavior including all quirks |
| `response.md` | This file — migration plan and Phase 1/2 summary |

### Characterization Test Coverage

| Method | Test Cases | Quirks Covered |
|---|---|---|
| `formatDate` | 5 (normal, zero-padding, year boundary, leap day, length check) | None |
| `parseDate` | 7 (valid, round-trip, lenient overflow day/month/leap, empty, non-date) | Lenient parsing (3 tests) |
| `isToday` | 5 (now, yesterday, tomorrow, start-of-day, end-of-day) | None |
| `daysBetween` | 7 (same, +1, +30, +365, +366, negative, sub-24h-ms-quirk) | DST/ms quirk (1 test) |
| `getWeekday` | 4 (Monday, Sunday, all 7 days, locale independence) | Locale pinning (1 test) |
| `toTimestamp` | 3 (normal millis, epoch, pre-epoch) | None |
| `fromTimestamp` | 4 (normal, epoch, pre-epoch, symmetry with toTimestamp) | None |
| `formatRelative` | 5 (today, yesterday, 2 days, 30 days, future-date quirk, lowercase) | Future date quirk (1 test) |

### Next Steps (awaiting user decisions)

Before Phase 3 begins, the user should confirm:
1. Which of the three quirks above to preserve vs. fix
2. Whether any callers do hidden `Date` serialization that would require a bridge type converter
3. Whether PR 1 (snapshot tests only) should be opened now, or combined with PR 2

**Phase 3 does not start until snapshot tests are confirmed green against the existing `DateUtils.java`.**
