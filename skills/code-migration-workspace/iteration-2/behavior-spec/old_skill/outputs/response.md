# Migration Planning Response: DateUtils.java

## Phase 1: Discover

### Target
- **File:** `DateUtils.java`
- **FROM:** `java.util.Date`, `java.text.SimpleDateFormat` (Java standard library)
- **TO:** `kotlin.time`, `kotlinx-datetime` (Kotlin multiplatform date/time APIs)
- **Category:** `logic` — pure utility class, no UI, no Gradle module boundary changes

### Codebase Impact Analysis

| Factor | Finding |
|---|---|
| **Callers** | Unknown (no codebase provided). Assumed: several callers across the app consuming `Date`-typed parameters and return values. |
| **Hidden consumers** | Potentially: serialization/deserialization code converting `Date` ↔ JSON, database converters (Room TypeConverters), any ProGuard keep rules referencing DateUtils. These would break silently if Date is replaced and must be searched explicitly in the real codebase. |
| **Module boundary** | Unknown. Assumed mixed into a single app module (common for utility classes). |
| **Test coverage** | None — explicitly stated. Zero safety net before migration. |
| **API stability** | **The public interface changes.** All 8 methods accept or return `java.util.Date`. After migration they will accept/return `kotlinx.datetime.LocalDate`, `Instant`, or `Long` — depending on the chosen API shape. All callers must be updated. |
| **Build speed** | Unknown. Module isolation not assumed necessary for a single utility class. |
| **KMP dependency compatibility** | `kotlinx-datetime` is fully KMP-compatible (`org.jetbrains.kotlinx:kotlinx-datetime`). No blocking dependency issues. |

### Strategy Proposal

**Option A — Parallel (Expand-Contract)** ← RECOMMENDED

> Preparation: Write characterization tests against the existing Java `DateUtils` (using a Kotlin test class that calls the Java methods). These tests are the snapshot — they must be green before any migration code is written.
>
> Migration:
> 1. Create `DateUtilsKt.kt` alongside `DateUtils.java`, implementing all 8 methods with `kotlinx-datetime` types.
> 2. Mark `DateUtils` methods `@Deprecated(level = WARNING)` pointing to the Kotlin equivalents.
> 3. Migrate callers one-by-one from `DateUtils.*` (Java, `Date` params) → `DateUtilsKt.*` (Kotlin, `LocalDate`/`Instant` params). Each caller change must keep the build green.
> 4. When all callers switched, delete `DateUtils.java`.
>
> PRs:
> - PR 1: Characterization tests only (`DateUtilsTest.kt`). No production code changes. Reviewers verify tests are green and match described behavior.
> - PR 2: Add `DateUtilsKt.kt` + `@Deprecated` annotations on `DateUtils`. Both compile together. No caller changes yet.
> - PR 3: Caller migrations (batched by module/screen if multiple exist).
> - PR 4: Delete `DateUtils.java` and remove `java.text.SimpleDateFormat` usage; confirm `java.util.Date` is no longer imported anywhere in migrated code.
>
> Effort: **low** (single file, pure logic, no UI)
> Risk: **low** (parallel allows rollback at any caller; tests catch regressions)
> Why: No tests means we cannot safely do in-place — any behavioral mistake would go undetected. Parallel gives us a green snapshot before touching callers, and the `@Deprecated` annotation turns the IDE into a migration guide with quick-fix support.

---

**Not offered: In-place**
The public interface changes (all params/returns shift from `Date` to `LocalDate`/`Instant`). In-place would require all callers to be updated simultaneously with no rollback seam. With zero test coverage, any regression is invisible until runtime. Wrong approach for this codebase state.

**Not offered: Branch by Abstraction**
DateUtils is a static utility class, not injected through an interface. Introducing an interface solely to swap the implementation adds ceremony with no caller-facing benefit here — callers will need updating anyway because the type signatures change.

**Not offered: Big Bang**
No meaningful coupling that makes incremental impractical. Big Bang would just mean doing Parallel without the safety — strictly worse.

---

### User Decision Point

The task specifies: assume **Parallel** is chosen. Proceeding to Phase 2: Snapshot.

---

## Phase 2: Snapshot

Since there is no existing test infrastructure to run, the snapshot consists of:
1. `behavior-spec.md` — the written behavioral contract
2. `DateUtilsTest.kt` — characterization tests that encode what `DateUtils.java` actually does, ready to be compiled and run against the Java implementation before any migration code is written

Both are written to the output directory. The tests are written as a Kotlin test class calling the (simulated) Java `DateUtils` methods. In a real project, this test file would be placed under `src/test/kotlin/` (or the appropriate source set) and run with `./gradlew test` to confirm green before Phase 3 starts.

### Quirks and Surprises Noted (from reading the description)

1. **`parseDate` uses lenient mode** — `SimpleDateFormat` lenient mode silently accepts out-of-range values (e.g., month 13 rolls over to January of next year). This is a quirk that `kotlinx-datetime` does not replicate — it throws on invalid input. This behavior must be a **conscious decision point** for the user: preserve the lenient behavior (requires explicit handling in the Kotlin impl) or treat invalid input as an error (stricter, safer, but a behavioral change). **Flagged in spec — user must decide.**

2. **`parseDate` return type is `Date` (nullable risk)** — `SimpleDateFormat.parse()` can throw `ParseException` or return null. The Java method as described swallows this (unclear) or propagates it. The snapshot tests must cover the parse failure path.

3. **`isToday` uses device timezone** — relies on `TimeZone.getDefault()` implicitly through `Calendar`. In `kotlinx-datetime`, the equivalent is `TimeZone.currentSystemDefault()`. Behavior is identical on Android, but must be made explicit.

4. **`formatRelative` timezone scope** — "today", "yesterday", "X days ago" are computed relative to the current day in the device timezone. If the device timezone changes between `formatDate` and `formatRelative` calls in the same session, results may be inconsistent. This is a pre-existing ambient risk, not introduced by migration, but worth documenting.

5. **`daysBetween` sign convention** — the description does not specify whether `daysBetween(past, future)` returns positive or negative. The characterization tests must pin this down. Assumed: `to - from` in days (positive when `to` is after `from`).

See `behavior-spec.md` and `DateUtilsTest.kt` for the full specification and test coverage.
