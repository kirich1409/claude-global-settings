# Behavior Specification: DateUtils
FROM: `java.util.Date` + `java.text.SimpleDateFormat` → TO: `kotlin.time` + `kotlinx-datetime`

## Public Interface

| Method / Property | Inputs | Output / Side Effect | Notes |
|---|---|---|---|
| `formatDate(date, pattern)` | `Date date`, `String pattern` | `String` — date formatted per pattern | Uses `SimpleDateFormat(pattern)`; pattern syntax is Java's `DateTimeFormatter`-compatible subset; locale and timezone are JVM defaults |
| `parseDate(dateStr, pattern)` | `String dateStr`, `String pattern` | `Date` — parsed date | Uses `SimpleDateFormat(pattern)`; throws `ParseException` (checked) on malformed input, or may propagate as unchecked depending on caller wrapping |
| `isToday(date)` | `Date date` | `Boolean` — true if date falls on today's calendar day | Comparison uses JVM default timezone; "today" is evaluated at call time |
| `daysBetween(start, end)` | `Date start`, `Date end` | `Long` — number of days from start to end | Sign behavior: likely positive when end > start; DST edge cases depend on implementation (millisecond division vs. Calendar rollover) |
| `addDays(date, days)` | `Date date`, `int days` | `Date` — new date with days added | Negative `days` subtracts; uses Calendar or millisecond arithmetic |
| `startOfDay(date)` | `Date date` | `Date` — same calendar day, time set to 00:00:00.000 | Timezone-sensitive: midnight is in JVM default timezone |
| `isBefore(date, reference)` | `Date date`, `Date reference` | `Boolean` — true if `date` is strictly before `reference` | Uses `Date.before()` or millisecond comparison; equal dates return false |
| `toIso8601(date)` | `Date date` | `String` — ISO 8601 formatted date string | Pattern is likely `yyyy-MM-dd'T'HH:mm:ss` or with timezone offset; exact format is a quirk (see below) |

## Normal Behaviors

- `formatDate` applies the caller-supplied pattern using `SimpleDateFormat`, respecting the JVM default locale and timezone. Two calls with the same `Date` but different patterns produce different strings.
- `parseDate` constructs a `SimpleDateFormat` from the given pattern and parses the string. The returned `Date` represents an absolute instant in time; timezone parsing behavior follows the pattern (if `z`/`Z` tokens present) or defaults to JVM timezone.
- `isToday` converts both the argument and the current system time to a calendar day in the JVM default timezone and checks if they match. A date from 23:59:59 yesterday is not today; 00:00:00 today is today.
- `daysBetween` returns the number of whole days between `start` and `end`. A common Java implementation divides the millisecond difference by `86_400_000L`; this can produce off-by-one results across DST transitions.
- `addDays` returns a new `Date` with the calendar day advanced by `days`. It does not mutate the input `Date`.
- `startOfDay` returns a new `Date` representing midnight (00:00:00.000) of the same calendar day as `date` in the JVM default timezone.
- `isBefore` returns `true` if and only if `date` is strictly earlier than `reference` in absolute time (milliseconds). Equal instants return `false`.
- `toIso8601` formats `date` to a fixed ISO 8601 string. It does not accept a caller-supplied pattern.

## Edge Cases

- `formatDate(date, "")` — empty pattern: `SimpleDateFormat("")` produces an empty string for any date.
- `parseDate("", pattern)` — empty string: throws `ParseException`; the migration must preserve this (throw or translate to an appropriate Kotlin exception).
- `parseDate(dateStr, pattern)` where `dateStr` does not match `pattern` — throws `ParseException`.
- `isToday` with a date exactly at midnight of today — returns `true`.
- `isToday` with a date one millisecond before midnight of today — returns `false`.
- `daysBetween(d, d)` — same instant: returns `0L`.
- `daysBetween(end, start)` where end < start — returns a negative long (or 0, depending on implementation; verify).
- `addDays(date, 0)` — returns a date equal to `date`.
- `addDays(date, -1)` — returns yesterday's date.
- `startOfDay` on a date already at midnight — returns a date equal to the input (same ms value after conversion).
- `isBefore(d, d)` — same instant: returns `false` (strictly before).
- `toIso8601` on a date at Unix epoch (Jan 1, 1970) — must produce a valid ISO 8601 string.

## Quirks (preserve exactly unless user decides otherwise)

- **`SimpleDateFormat` is not thread-safe.** The Java implementation creates a new `SimpleDateFormat` per call (or re-uses a shared instance with race conditions). If a shared instance is used, concurrent calls to `formatDate`/`parseDate` can corrupt results silently. The Kotlin migration eliminates this quirk — `DateTimeFormatter` (or kotlinx-datetime) is immutable and thread-safe.
- **`parseDate` exception type.** `SimpleDateFormat.parse()` throws checked `ParseException`. Java static methods that do not declare `throws` have likely wrapped it in a `RuntimeException` or swallowed it (returning `null` or an epoch date). The exact exception handling must be inspected and preserved — or explicitly changed with user approval.
- **`toIso8601` timezone behavior.** `SimpleDateFormat` with pattern `yyyy-MM-dd'T'HH:mm:ss` (no zone) formats in JVM default timezone, producing local time without offset. Pattern `yyyy-MM-dd'T'HH:mm:ssZ` includes zone offset. The exact output format is a quirk to confirm: the migration must produce the same string format.
- **`isToday` and `daysBetween` timezone sensitivity.** Both methods implicitly use `TimeZone.getDefault()`. If the JVM default timezone differs from UTC, dates near midnight will behave differently than in UTC. The Kotlin migration must use the same "system default" timezone to preserve behavior, unless the user explicitly decides to change to UTC.
- **`daysBetween` DST off-by-one.** If implemented as `(end.time - start.time) / 86_400_000L`, crossing a DST boundary (23-hour or 25-hour day) returns an off-by-one result. This is a known Java quirk; preserve it unless the user marks it a bug to fix.
- **Null handling.** Java `Date` parameters are nullable — passing `null` to any method will throw a `NullPointerException`. The Kotlin migration should use non-nullable types and fail with an equivalent exception (or `IllegalArgumentException`) at the same boundary.

## Out of Scope

- Any changes to the public method signatures (e.g., changing `Date` to `Instant`/`LocalDate`/`LocalDateTime` in the public API) are out of scope unless the user explicitly decides to change the API surface.
- Fixing the thread-safety quirk of `SimpleDateFormat` is incidental; the migration eliminates it naturally. Not a separate action item.
- Locale-aware formatting beyond what the original `SimpleDateFormat` provided.
- Timezone parameter added to methods that previously used JVM default — out of scope unless user requests it.
