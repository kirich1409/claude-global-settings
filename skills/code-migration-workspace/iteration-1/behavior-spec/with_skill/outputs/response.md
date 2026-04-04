# Migration Simulation: DateUtils.java → Kotlin time APIs
## Phases 1 and 2 (stopping before Phase 3)

---

## Phase 1: Discover

### Step 1 — Reading the target

I would read `DateUtils.java` thoroughly. Based on the description, I expect to find:

- `import java.util.Date;`
- `import java.text.SimpleDateFormat;`
- `import java.util.Calendar;` (likely used for `isToday`, `daysBetween`, `getWeekday`)
- `import java.util.Locale;` (possibly, for `SimpleDateFormat` formatting)
- 8 public static methods, all operating on `java.util.Date` or `long`
- No instance state — a pure utility class

### Step 2 — FROM technology

**FROM:** Java standard library date/time APIs:
- `java.util.Date` — the core data type
- `java.text.SimpleDateFormat` — for formatting and parsing
- `java.util.Calendar` — for field extraction (day, month, year, day-of-week)
- `java.util.TimeZone` — implicitly via `TimeZone.getDefault()`

These are the classic pre-Java-8 date APIs. They are mutable, not thread-safe, and timezone-implicit.

### Step 3 — TO technology

**TO:** Kotlin modern time APIs:
- `kotlinx-datetime` (`org.jetbrains.kotlinx:kotlinx-datetime`) — for `LocalDate`, `Instant`, `Clock`, `DateTimeUnit`, `TimeZone`, `DateTimePeriod`
- `kotlin.time` — for `Duration`, `DurationUnit`

This matches the user's explicit instruction.

### Step 4 — Categorize

`DateUtils.java` is **`logic`** only:
- Pure data transformation — no UI, no shared module boundary, no Gradle config
- All methods are static; no dependency injection, no side effects beyond reading the system clock in `isToday` and `formatRelative`

### Step 5 — Codebase impact analysis (simulated)

Since I'm not reading the actual codebase, here is what I would do and what I would expect to find:

**Callers search:** I would search for `DateUtils.` across all `.java` and `.kt` files. Given this is described as a utility class in a typical Android project, I would expect 5–20 call sites across UI layers (adapters, ViewModels, fragments) and possibly data layers (Room TypeConverters, repository mappers).

**Hidden consumers to check:**
- Room `TypeConverter` classes that might delegate to `DateUtils.toTimestamp` / `fromTimestamp` — these are critical and easy to miss
- Proguard/R8 keep rules: `-keep class **.DateUtils` would need to be reviewed if the public API changes
- Any serialization/deserialization code that uses `formatDate`/`parseDate` for persistence (database, SharedPreferences, network) — the output format must not change
- Any tests that assert on the string output of `formatDate` or `formatRelative`

**Module boundary:** Assumed to be inside a single `:app` or `:core` module, not in its own Gradle module. Isolation is not proposed (see strategy rationale below).

**Test coverage:** The task states there are **no existing tests**. This is the most important constraint — it means Phase 2 must write characterization tests from scratch before touching any code.

**API stability:** The public method signatures take `java.util.Date` and return `String`/`Long`/`Boolean`. After migration, the signatures will change to use `Instant`, `LocalDate`, or `kotlinx.datetime` types. This is a **breaking API change** for all callers. The Parallel (Expand-Contract) strategy is therefore warranted if there are many callers.

**Build speed:** Unknown without reading the project, but assumed normal for an Android project.

### Step 6 — Strategy options

> **Option A — Parallel (Expand-Contract)** *(recommended)*
> Preparation: Write characterization tests against the current Java implementation to lock down behavior. Add `kotlinx-datetime` Gradle dependency.
> Migration: Create `DateUtilsKt.kt` alongside the existing `DateUtils.java`. Implement all 8 methods using kotlinx-datetime. Migrate callers one-by-one from `DateUtils.*` to `DateUtilsKt.*`, building after each batch. Delete `DateUtils.java` when all callers are switched.
> Effort: medium
> Risk: low
> Why: No existing tests means we must write them first — parallel lets us validate the new implementation against the old before touching callers. The API surface change (Date → Instant/LocalDate) means each caller needs deliberate attention, and doing them one-by-one keeps the build green throughout.

> **Option B — In-place**
> Preparation: Write characterization tests. Add `kotlinx-datetime` dependency. Introduce a `java.util.Date` ↔ `Instant` bridge layer temporarily so callers don't break mid-migration.
> Migration: Rewrite all 8 methods inside `DateUtils.java` (renamed to `DateUtils.kt`). Update all callers in one pass.
> Effort: medium
> Risk: medium
> Why: Simpler if the caller count is small (< 5). The risk is that changing all callers at once makes it harder to isolate a regression. Without existing tests, the characterization tests are our only safety net — parallel gives better isolation.

> **Option C — Branch by Abstraction**
> Preparation: Extract a `DateFormatter` interface with the same 8 methods. Inject it instead of using static calls. Create `KotlinDateFormatter` implementing the interface.
> Migration: Swap the DI binding. Delete `DateUtils.java`.
> Effort: high
> Risk: low
> Why: Only worthwhile if callers already use dependency injection. Refactoring static call sites to injected interfaces is extra scope that wasn't asked for. Not recommended unless the team is already moving in that direction.

**My recommendation: Option A.** The absence of existing tests makes characterization test coverage before touching any caller essential, and the parallel approach gives us the cleanest way to validate the new implementation against the old before any caller sees it.

---

*I would now present these options to the user and wait for their choice. The user has not chosen in this simulation, so I will proceed assuming Option A was selected for the purposes of Phase 2.*

---

## Phase 2: Snapshot

### Behavior Specification

Before writing any tests, I produce `behavior-spec.md` (saved alongside this response). This is the source of truth for what the migration must preserve.

Key findings captured in the spec:

1. **Timezone implicit dependency** — the single biggest quirk. All methods that deal with calendar dates (`parseDate`, `daysBetween`, `isToday`, `getWeekday`) use `TimeZone.getDefault()` implicitly through `SimpleDateFormat` and `Calendar`. The Kotlin migration must use `TimeZone.currentSystemDefault()` everywhere to match this behavior.

2. **Lenient parsing** — `SimpleDateFormat` is lenient by default. `parseDate("2024-02-30")` returns `2024-03-01` rather than throwing. This is a quirk that must be preserved unless the user explicitly chooses strict mode.

3. **Format pattern** — the exact format string used in `formatDate`/`parseDate` is not specified in the task description. I would read it from the source. The migration must use the identical pattern.

4. **`formatRelative` thresholds** — the exact label strings and cutoff values (what makes something "today" vs "yesterday" vs "X days ago") are implementation-specific and must be read from the source before writing tests.

5. **`toTimestamp`/`fromTimestamp` are millis** — must not accidentally change to seconds or nanoseconds in the Kotlin version.

### Characterization tests (what I would write — not yet written since we stop before Phase 3)

Since there are no existing tests, I would write a new `DateUtilsTest.kt` (or `DateUtilsTest.java`) that pins down:

**For `formatDate`:**
- A fixed known date → assert exact string output (this reveals the format pattern)
- A date at midnight UTC vs midnight local time (to reveal timezone behavior)

**For `parseDate`:**
- The output of `formatDate` round-trips back to the same calendar date
- A known format string → assert the resulting `Date`'s time components
- Malformed input → assert exception type
- "Lenient" input like `"2024-02-30"` → assert it rolls over to `2024-03-01`

**For `daysBetween`:**
- Same date → `0`
- One day apart → `1`
- `end < start` → assert sign (negative or absolute)
- DST transition date pair (e.g. spring-forward night) → captures timezone quirk

**For `isToday`:**
- `new Date()` (now) → `true`
- Yesterday → `false`
- Tomorrow → `false`

**For `toTimestamp` / `fromTimestamp`:**
- Round-trip: `toTimestamp(fromTimestamp(ms)) == ms`
- Epoch zero: `fromTimestamp(0L)` → `Date` at `1970-01-01T00:00:00.000Z`

**For `formatRelative`:**
- Now → `"Today"` (or whatever the label is)
- Yesterday → `"Yesterday"` (or the label)
- 3 days ago → `"3 days ago"` (reveals label format)
- Future date → assert what actually happens (may be surprising)

**For `getWeekday`:**
- A known Monday → `"Monday"` (or `"Mon"` — reveals format)
- A known Sunday → correct label
- Locale check: run with a non-English locale to reveal whether locale is pinned

### Hard stop before Phase 3

Per the skill's hard rule: **Phase 3 does not start until the snapshot is complete and green.**

Since this is a simulation (no actual code to run), the stopping point is here. In a real migration:
- I would present `behavior-spec.md` to the user for review and corrections
- I would write and run all characterization tests
- All tests must pass (green) before touching a single line of `DateUtils.java`
- If any test cannot be made to compile or pass, I stop and discuss with the user

---

## Summary

| Phase | Status |
|-------|--------|
| Phase 1: Discover | Complete (simulated) |
| Phase 2: Snapshot — behavior-spec.md | Complete (see `behavior-spec.md`) |
| Phase 2: Snapshot — characterization tests | Described but not written (requires actual source + running JVM) |
| Phase 3: Migrate | NOT STARTED — stopping here as instructed |

Files produced:
- `behavior-spec.md` — full behavioral contract for the migration
- `response.md` — this document
