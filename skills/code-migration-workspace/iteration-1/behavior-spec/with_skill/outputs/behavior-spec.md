# Behavior Specification: DateUtils
FROM: Java (`java.util.Date`, `java.text.SimpleDateFormat`) → TO: Kotlin (`kotlin.time`, `kotlinx-datetime`)

---

## Public Interface

| Method / Property | Inputs | Output / Side Effect | Notes |
|---|---|---|---|
| `formatDate(date: Date): String` | `java.util.Date`; nullable not specified — assumed non-null | Formatted date string, e.g. `"2024-03-15"` | Format pattern inferred as `yyyy-MM-dd` (ISO-like); exact pattern must be confirmed from source. Returns `""` or throws on null depending on implementation. |
| `parseDate(dateStr: String): Date` | Non-null `String` in the format `formatDate` produces | `java.util.Date` representing midnight of that date in the **default system timezone** | `SimpleDateFormat` without explicit `TimeZone` uses `TimeZone.getDefault()` — a critical timezone quirk. Throws `ParseException` (possibly wrapped) on malformed input. |
| `daysBetween(start: Date, end: Date): Long` | Two non-null `java.util.Date` values | Number of whole calendar days between `start` and `end` | Sign: likely `end - start` (positive when end is after start). Truncation method (floor vs round) determines behavior for fractional days — needs confirmation. Result may be negative if `start > end`. |
| `isToday(date: Date): Boolean` | Non-null `java.util.Date` | `true` if `date` falls on today's calendar date in the **default system timezone** | Comparison is date-only (year/month/day), not time-of-day. Timezone dependency is implicit. |
| `toTimestamp(date: Date): Long` | Non-null `java.util.Date` | Unix epoch milliseconds (`date.time`) | Straightforward — this is `Date.getTime()`. |
| `fromTimestamp(timestamp: Long): Date` | Unix epoch milliseconds as `Long` | `java.util.Date` constructed from the given millis | Straightforward — this is `Date(timestamp)`. Negative values (pre-epoch) are technically valid. |
| `formatRelative(date: Date): String` | Non-null `java.util.Date` | Human-readable relative string, e.g. `"Today"`, `"Yesterday"`, `"3 days ago"`, `"2 weeks ago"` | Relative to the **current time at call time**. Exact thresholds and labels (what counts as "today", "yesterday", week vs day boundary) need to be confirmed from source. Likely uses default locale. |
| `getWeekday(date: Date): String` | Non-null `java.util.Date` | Full or abbreviated weekday name, e.g. `"Monday"` or `"Mon"` | Locale-dependent via `SimpleDateFormat("EEEE")` or similar. Returns English name if default locale is English; may differ on devices with non-English locales. |

---

## Normal Behaviors

- `formatDate` produces a consistent, parseable string that `parseDate` can round-trip (i.e. `parseDate(formatDate(d))` recovers the same calendar date, though not necessarily the same time-of-day).
- `parseDate` always returns a `Date` at midnight (00:00:00.000) of the given date in the default system timezone — the time component is lost.
- `daysBetween` computes the difference in whole days, using the default timezone to determine what constitutes a "day boundary".
- `isToday` returns `true` for any `Date` whose year/month/day in the default timezone matches today's year/month/day.
- `toTimestamp` and `fromTimestamp` are inverses of each other: `toTimestamp(fromTimestamp(ms)) == ms` for all valid `Long` inputs.
- `formatRelative` returns a short human-readable label for how far in the past `date` is relative to now. Expected labels (to confirm): `"Today"`, `"Yesterday"`, `"X days ago"`, `"X weeks ago"`, possibly `"X months ago"`.
- `getWeekday` returns the name of the day-of-week for the given date in the default timezone and default locale.

---

## Edge Cases

- `formatDate` / `parseDate`: dates at DST transition boundaries (clocks spring forward/fall back) may produce surprising round-trip results because `SimpleDateFormat` without explicit timezone uses the default timezone.
- `daysBetween(d, d)` (same date): expected to return `0`.
- `daysBetween(end, start)` where `end < start`: expected to return a negative value (but confirm — some implementations return `abs()`).
- `isToday` called exactly at midnight: `Date` with time `23:59:59.999` is "today"; `Date` with time `00:00:00.000` tomorrow is not — standard behavior.
- `fromTimestamp(0L)`: returns `Date` representing `1970-01-01T00:00:00.000Z` (Unix epoch). Valid input.
- `fromTimestamp(Long.MIN_VALUE)` / large negative values: technically accepted by `Date(long)` constructor; behavior is defined but unusual.
- `formatRelative` on a future date: behavior is unspecified — may return `"0 days ago"`, `"Today"`, or a negative value string. Needs to be confirmed from source.
- `getWeekday` on dates before the Gregorian calendar reform (pre-1582): `SimpleDateFormat` behavior is implementation-defined; effectively out of scope.
- `parseDate` on empty string `""`: throws (likely `ParseException` wrapped or unwrapped).
- `parseDate` on a string with correct format but invalid date (e.g. `"2024-02-30"`): `SimpleDateFormat` in lenient mode (default) will roll over to `2024-03-01`; in strict mode it throws. **This is a quirk to confirm.**

---

## Quirks (preserve exactly unless user decides otherwise)

1. **Default timezone dependency**: `SimpleDateFormat` without an explicit `TimeZone` uses `TimeZone.getDefault()`. This means `parseDate`, `daysBetween`, `isToday`, and `getWeekday` all produce results that vary by the device's timezone setting. The Kotlin/kotlinx-datetime migration must replicate this behavior (use `TimeZone.currentSystemDefault()`) unless the user explicitly chooses to make timezone handling explicit.

2. **Lenient date parsing**: `SimpleDateFormat` is lenient by default. `parseDate("2024-02-30")` would return `2024-03-01` rather than throwing. The migration must either replicate this (using `DateTimeFormatter` with lenient parsing or manual overflow handling) or the user must explicitly decide to make it strict.

3. **`formatDate` format pattern**: The exact pattern (`yyyy-MM-dd`? `MM/dd/yyyy`? `dd-MM-yyyy`?) is inferred — must be confirmed from the source. The migration must use the identical pattern string to avoid breaking callers that depend on the output format.

4. **`getWeekday` locale**: The day name is locale-sensitive. If callers expect English regardless of device locale, a `Locale.ENGLISH` should be pinned — but this may already be the case in the source. To be confirmed.

5. **`formatRelative` thresholds**: The exact cutoff values (when does "today" become "yesterday", when does it switch from days to weeks) and the exact label strings are implementation-specific. These must be captured exactly for callers that pattern-match on the output.

6. **`toTimestamp` / `fromTimestamp` millisecond precision**: `Date.getTime()` is in milliseconds. `Instant` in kotlinx-datetime supports nanoseconds but `toLong()` on an epoch-milliseconds representation gives back milliseconds. Ensure the Kotlin implementation does not accidentally change the unit to seconds or nanoseconds.

---

## Out of Scope

- Changing the timezone behavior from implicit (system default) to explicit parameter — this would be a breaking API change. Not in scope unless user explicitly decides to change the signature.
- Changing the date format string used by `formatDate`/`parseDate` — callers depend on it.
- Adding new public methods or removing existing ones.
- Fixing the lenient-parsing quirk (item 2 above) — treat as a preserved quirk unless the user explicitly chooses to make it strict.
- Thread safety improvements: `SimpleDateFormat` is not thread-safe; kotlinx-datetime formatters are. This is a silent improvement that doesn't affect behavior but should be noted.
