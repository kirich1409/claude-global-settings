# Behavior Specification: DateUtils
FROM: Java (`java.util.Date`, `java.text.SimpleDateFormat`, `java.util.Calendar`) → TO: Kotlin (`kotlin.time`, `kotlinx-datetime`)

---

## Public Interface

| Method / Property | Inputs | Output / Side Effect | Notes |
|---|---|---|---|
| `formatDate(date: Date): String` | `java.util.Date`; assumed non-null (behavior with null unknown without reading code) | Formatted date string | Format pattern unknown — likely `"yyyy-MM-dd"` or locale-specific `"MMM d, yyyy"`. **Must confirm from source.** |
| `parseDate(input: String): Date` | Date string matching format used by `formatDate` | `java.util.Date` | Behavior on malformed input: `SimpleDateFormat.parse` throws `ParseException` — likely propagated or wrapped. **Must confirm.** |
| `daysBetween(a: Date, b: Date): Long` (or `Int`) | Two `java.util.Date` values | Number of whole calendar days from `a` to `b` | Sign convention: positive if `b` is after `a`, negative if before? Or absolute? **Must confirm from source.** DST gaps may cause off-by-one with naive ms division. |
| `isToday(date: Date): Boolean` | `java.util.Date` | `true` if date falls on today's calendar day in the device's default timezone | Uses `Calendar.getInstance()` or `new Date()` — timezone-sensitive. |
| `toTimestamp(date: Date): Long` | `java.util.Date` | `date.getTime()` — milliseconds since Unix epoch | Straightforward wrapper. Likely returns `0L` for epoch. |
| `fromTimestamp(ms: Long): Date` | Unix epoch milliseconds | `new Date(ms)` | Inverse of `toTimestamp`. Accepts `0L`, negative values. |
| `formatRelative(date: Date): String` | `java.util.Date` | Human-readable relative string (e.g., "Today", "Yesterday", "3 days ago") | Exact labels, thresholds (days vs weeks vs months), and locale handling unknown. **Critical to capture from source.** |
| `getWeekday(date: Date): String` (or `Int`) | `java.util.Date` | Day name (e.g., "Monday") or day index (e.g., `Calendar.MONDAY = 2`) | Return type unknown. If String: locale-sensitive. If Int: 1-based or 0-based? **Must confirm from source.** |

---

## Normal Behaviors

- `formatDate` / `parseDate` form a round-trip: `parseDate(formatDate(d))` produces a `Date` equal to `d` (modulo time-of-day truncation if format excludes time).
- `daysBetween` counts whole days, not fractional (i.e., 23h 59m apart on different calendar days = 1 day).
- `isToday` uses the device default timezone — a date at 23:59 UTC may be "tomorrow" in UTC+1.
- `toTimestamp` / `fromTimestamp` are exact inverses: `fromTimestamp(toTimestamp(d)).equals(d)` is always true.
- `formatRelative` distinguishes at minimum: today, yesterday, and older dates. May also include "tomorrow" if the method accepts future dates.
- `getWeekday` returns a value derived from `Calendar.DAY_OF_WEEK` or equivalent.

---

## Edge Cases

- `formatDate(new Date(0))` — epoch date (Jan 1, 1970). Must not throw.
- `parseDate("")` — empty string. Likely throws `ParseException` or returns null.
- `parseDate("not-a-date")` — malformed string. Same as above.
- `daysBetween(d, d)` — same date, same instant: expected result is `0`.
- `daysBetween(b, a)` where `b > a` — result is negative or absolute? **Must confirm.**
- `daysBetween` across a DST transition — naive `(b.time - a.time) / 86_400_000` may return wrong value (23h gap = 0 days). Calendar-based math handles this correctly.
- `isToday` near midnight — a date at 23:59:59 the previous day must return `false`.
- `fromTimestamp(0L)` — epoch date. Must not throw.
- `fromTimestamp(Long.MIN_VALUE)` — extreme negative. Behavior unspecified; likely not guarded.
- `formatRelative` with a future date — behavior unknown. May return a nonsensical label or throw.

---

## Quirks (preserve exactly unless user decides otherwise)

- `SimpleDateFormat` is **not thread-safe**. If `formatDate`/`parseDate` share a static `SimpleDateFormat` instance, concurrent calls are a latent race condition. **This is a bug, not a feature — but preserve the format pattern exactly; flag the thread-safety issue to the user as a separate concern.**
- Default timezone is used implicitly throughout. The migration to `kotlinx-datetime` must preserve this behavior (use `TimeZone.currentSystemDefault()`) unless the user explicitly decides to introduce explicit timezone parameters.
- `getWeekday` likely returns locale-aware day names via `Calendar`/`DateFormatSymbols`. Locale is the JVM default. The migration must preserve this if the return type is `String`.
- `formatRelative` thresholds (when does "3 days ago" become "last week"?) are implementation-defined and must be preserved exactly.
- `parseDate` exception vs null behavior — if the original swallows `ParseException` and returns `null`, that nullability contract must be preserved (as `Date?` in Kotlin). If it propagates, the Kotlin version must also throw (using `IllegalArgumentException` or a wrapped exception).

---

## Out of Scope

_(Items that will intentionally change after migration — to be confirmed with user before Phase 3)_

- `java.util.Date` input/output types will be replaced by `kotlinx-datetime` types (`Instant`, `LocalDate`) in the Kotlin API. **Callers must be updated.** Java interop shims (`@JvmStatic`, `@JvmName`) may be added if Java callers exist.
- `SimpleDateFormat` thread-safety bug will be resolved as a side effect (kotlinx-datetime formatters are immutable). This is an improvement, not a regression — but must be noted to the user.
- Static Java-style utility methods become top-level Kotlin functions or methods on a Kotlin object. The call-site syntax changes (`DateUtils.formatDate(d)` → `DateUtils.formatDate(instant)` or `instant.format(...)`).

---

## Notes for Migration

- `kotlinx-datetime` is a separate Gradle dependency — must be added to `build.gradle.kts` before Phase 3.
- `Instant` replaces `Date` for most purposes; `LocalDate` replaces date-only values (no time component).
- `Clock.System.now()` replaces `new Date()` / `System.currentTimeMillis()` for "now".
- `TimeZone.currentSystemDefault()` preserves the implicit default-timezone behavior.
- `DateTimeFormat` (kotlinx-datetime 0.5+) or `LocalDate.parse` with format string replaces `SimpleDateFormat`.
- `daysBetween` can use `date1.until(date2, DateTimeUnit.DAY, timezone)` on `Instant`, or `LocalDate.daysUntil(LocalDate)` — the latter is simpler for whole-day arithmetic.
