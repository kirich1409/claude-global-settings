# Behavior Specification: DateUtils
FROM: `java.util.Date` + `java.text.SimpleDateFormat` → TO: `kotlin.time` + `kotlinx-datetime`

---

## Public Interface

| Method | Inputs | Output / Side Effect | Notes |
|---|---|---|---|
| `formatDate(date: Date): String` | Non-null `java.util.Date` | ISO-8601 date string `"yyyy-MM-dd"` | Format is fixed; no locale dependency; no timezone handling documented (uses default timezone implicitly) |
| `parseDate(str: String): Date` | String in `"yyyy-MM-dd"` format | `java.util.Date` representing midnight of that date in the **default timezone** | `SimpleDateFormat` is set to **lenient mode** — out-of-range values roll over (e.g., `"2024-13-01"` → Feb 1 2025). Throws `ParseException` (or wraps it) on completely unparseable input. |
| `isToday(date: Date): Boolean` | Non-null `java.util.Date` | `true` if the date falls on the current calendar day in the **device timezone** | Comparison is calendar-day, not millisecond. Time component is ignored. Uses `TimeZone.getDefault()` implicitly. |
| `daysBetween(from: Date, to: Date): Int` | Two non-null `java.util.Date` instances | Integer number of days from `from` to `to` | Sign convention: positive when `to` is after `from`, negative when before. Time-of-day components are stripped (only calendar date matters). Uses default timezone for day boundary calculation. |
| `getWeekday(date: Date): String` | Non-null `java.util.Date` | Full English weekday name: `"Monday"`, `"Tuesday"`, `"Wednesday"`, `"Thursday"`, `"Friday"`, `"Saturday"`, `"Sunday"` | Locale: English (en). Not locale-sensitive — always English regardless of device locale. Uses default timezone. |
| `toTimestamp(date: Date): Long` | Non-null `java.util.Date` | Milliseconds since Unix epoch (UTC) | Equivalent to `date.time`. Always UTC-based regardless of timezone. |
| `fromTimestamp(millis: Long): Date` | Milliseconds since Unix epoch | `java.util.Date` | Inverse of `toTimestamp`. `fromTimestamp(toTimestamp(d)) == d` for any `Date d`. |
| `formatRelative(date: Date): String` | Non-null `java.util.Date` | Human-readable relative string | Returns `"today"` if same calendar day as now (device timezone). Returns `"yesterday"` if one calendar day before today. Returns `"X days ago"` (e.g., `"3 days ago"`) for 2 or more days before today. Behavior for **future dates** is unspecified — see Quirks. |

---

## Normal Behaviors

- `formatDate` always produces an 8-character date portion in the fixed pattern `yyyy-MM-dd`, zero-padded (e.g., `"2024-01-05"` not `"2024-1-5"`).
- `parseDate` interprets the input as a date in the default system timezone; the resulting `Date`'s millisecond value reflects midnight of that day in that timezone.
- `isToday` correctly handles dates that are the same calendar day but different times (e.g., 00:00:01 and 23:59:59 on the same day both return `true`).
- `daysBetween` strips time components before computing the difference — only the calendar date matters.
- `getWeekday` always returns one of exactly seven specific English strings (capitalized, full name).
- `toTimestamp` / `fromTimestamp` are exact inverses: no rounding, no truncation.
- `formatRelative` uses the current wall-clock time in the device timezone to determine "today". Two consecutive calls may return different results if called across midnight.

---

## Edge Cases

- `formatDate(Date(0))` — epoch (1970-01-01 UTC). Result depends on device timezone: in UTC+ zones the date is still `"1970-01-01"`; in UTC- zones it may be `"1969-12-31"`.
- `parseDate("2024-02-29")` — valid in a leap year (2024 is a leap year), should parse correctly.
- `parseDate("2024-02-30")` — invalid date. In lenient mode: rolls over to `"2024-03-01"`. This is preserved behavior — **see Quirks**.
- `parseDate("not-a-date")` — completely invalid input. `SimpleDateFormat.parse()` throws `ParseException`. The Java method either propagates it or wraps it. Tests must pin down which.
- `daysBetween(d, d)` — same date: returns `0`.
- `daysBetween(future, past)` — `to` before `from`: returns negative integer.
- `isToday` called at 00:00:00 vs 23:59:59 on the same day: both return `true`.
- `formatRelative` with a date exactly 1 day ago at a different time of day (e.g., yesterday at 23:00, now is today at 01:00): must return `"yesterday"` — calendar-day comparison, not 24-hour window.
- `fromTimestamp(Long.MIN_VALUE)` / `fromTimestamp(Long.MAX_VALUE)` — extreme values; `java.util.Date` accepts them. Behavior is technically valid. New implementation must handle or document the limit.
- `formatRelative` with a future date: unspecified — behavior depends on implementation (might return negative days, might crash, might say "0 days ago"). **Must be tested to characterize actual behavior, then pinned.**

---

## Quirks (preserve exactly unless user decides otherwise)

1. **`parseDate` lenient rollover** — `SimpleDateFormat` in lenient mode silently accepts invalid dates and rolls them over. `"2024-02-30"` becomes `"2024-03-01"`. `"2024-13-01"` becomes `"2025-01-01"`. `kotlinx-datetime` throws on these inputs by default. **This quirk is a flag for user decision:** preserve lenient behavior (requires explicit wrapping logic in Kotlin impl), or treat invalid input as an error (stricter, breaking change for any callers passing invalid strings). **Decision required before Phase 3.**

2. **Implicit default timezone** — `formatDate`, `parseDate`, `isToday`, `daysBetween`, and `getWeekday` all depend on `TimeZone.getDefault()` implicitly via `Calendar`/`SimpleDateFormat`. This is replicated exactly in the new implementation using `TimeZone.currentSystemDefault()` from `kotlinx-datetime`. No behavioral change — but it's implicit and worth making explicit in the new API.

3. **`getWeekday` locale hardcoding** — The method returns English weekday names regardless of device locale. This is either intentional (English-only app) or a latent bug. The migration preserves this behavior using `Locale.ENGLISH` explicitly. **If the app should be locale-sensitive, this is the right moment to fix it — flag to user.**

4. **`formatRelative` future date behavior** — The description does not specify what happens when `date` is in the future. The characterization test must call `formatRelative` with a future date and pin whatever the implementation returns. The migration must preserve that output. If the current implementation crashes or returns nonsense for future dates, that is not fixed during migration — it is preserved or flagged.

5. **`toTimestamp` is UTC, `parseDate`/`formatDate` are timezone-local** — mixing these APIs across a timezone boundary can produce surprising results. E.g., `parseDate("2024-01-01")` in UTC-5 gives a `Date` whose `getTime()` is `2024-01-01T05:00:00Z` (not midnight UTC). This is pre-existing behavior and is preserved — but callers relying on specific timestamp values should be aware.

---

## Out of Scope

- Changing method signatures from `Date`-based to `LocalDate`/`Instant`-based — this happens in Phase 3 (the new `DateUtilsKt.kt`). The behavior spec describes what the **old** implementation does, and is the contract the new implementation must match.
- Adding timezone parameters to any method — not in scope for this migration.
- Fixing the lenient-parse behavior — only if user explicitly decides in response to Quirk #1.
- Fixing the locale-sensitivity of `getWeekday` — only if user explicitly decides in response to Quirk #3.
- Thread-safety of `SimpleDateFormat` — `SimpleDateFormat` is not thread-safe. The new `kotlinx-datetime` formatters are thread-safe. This is an implicit improvement, not a behavioral change visible to callers.
