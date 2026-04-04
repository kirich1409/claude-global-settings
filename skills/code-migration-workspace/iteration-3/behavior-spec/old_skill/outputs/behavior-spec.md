# Behavior Specification: DateUtils
FROM: Java (`java.util.Date`, `java.text.SimpleDateFormat`) → TO: Kotlin (`kotlin.time`, `kotlinx-datetime`)

## Public Interface

| Method | Inputs | Output / Side Effect | Notes |
|---|---|---|---|
| `formatDate(Date date, String pattern)` | `date`: any `java.util.Date`; `pattern`: `SimpleDateFormat`-compatible pattern string | `String` — formatted representation of the date | Locale-sensitive (uses default JVM locale); throws `IllegalArgumentException` if pattern is invalid; behavior undefined for `null` date or `null` pattern (likely NPE) |
| `parseDate(String dateStr, String pattern)` | `dateStr`: date string; `pattern`: `SimpleDateFormat`-compatible pattern string | `java.util.Date` — parsed result, or throws `ParseException` (wrapped or unchecked) | `SimpleDateFormat` is lenient by default — e.g., month `13` silently overflows to January of the next year; returns `null` or throws depending on implementation detail |
| `isToday(Date date)` | `date`: any `java.util.Date` | `boolean` — `true` if the date falls on today's calendar date in the default JVM timezone | Timezone-sensitive: uses `Calendar.getInstance()` or equivalent with the system default timezone; midnight boundary is calendar-date midnight in that timezone |
| `daysBetween(Date start, Date end)` | `start`, `end`: any `java.util.Date` | `long` — number of whole days between start and end | Direction: likely `end - start` expressed as days (may be negative if end < start); based on millisecond difference divided by `86400000`, ignoring DST — meaning a DST-transition day may return an off-by-one result |
| `addDays(Date date, int days)` | `date`: any `java.util.Date`; `days`: integer (positive or negative) | `java.util.Date` — new date shifted by `days` calendar days | Implemented via `Calendar.add(Calendar.DAY_OF_MONTH, days)` or millisecond arithmetic; DST handling depends on implementation; negative `days` subtracts |
| `startOfDay(Date date)` | `date`: any `java.util.Date` | `java.util.Date` — the same calendar date at 00:00:00.000 in the default JVM timezone | Timezone-sensitive; uses `Calendar` to zero out hour, minute, second, millisecond fields |
| `isBefore(Date date, Date reference)` | `date`, `reference`: any `java.util.Date` | `boolean` — `true` if `date` is strictly before `reference` | Delegates to `date.before(reference)` or equivalent millisecond comparison; equal timestamps return `false` |
| `toIso8601(Date date)` | `date`: any `java.util.Date` | `String` — ISO-8601 formatted date-time string | Format is almost certainly `"yyyy-MM-dd'T'HH:mm:ss"` or `"yyyy-MM-dd'T'HH:mm:ssZ"` (with or without timezone offset); timezone used is the default JVM timezone unless the format includes `'Z'` literal or `ZZ` offset |

## Normal Behaviors

- `formatDate` converts a `Date` to a human-readable string using any `SimpleDateFormat` pattern (e.g., `"dd/MM/yyyy"`, `"MMMM d, yyyy"`).
- `parseDate` performs the inverse: turns a formatted string back into a `Date` using the matching pattern. Lenient parsing is the `SimpleDateFormat` default.
- `isToday` compares calendar year, month, and day of the input date against today's date, both in the default system timezone.
- `daysBetween` returns a signed day count; positive when `end` is after `start`.
- `addDays` returns a new `Date` object; the input is not mutated.
- `startOfDay` returns a new `Date` with time components set to zero (midnight) in the system timezone.
- `isBefore` returns `true` only for strictly-before; same instant returns `false`.
- `toIso8601` always produces a fixed-format ISO string; no locale variation in output (digits only, fixed separators).

## Edge Cases

- `formatDate` with an empty pattern `""` — returns the date formatted with an empty pattern, which in `SimpleDateFormat` produces an empty string.
- `parseDate` with lenient mode on `"2024-13-01"` using pattern `"yyyy-MM-dd"` — silently produces `2025-01-01` (January 1, 2025) rather than throwing.
- `parseDate` with a string that does not match the pattern — throws `ParseException` (either propagated or wrapped in a `RuntimeException`, depending on implementation).
- `isToday` called at exactly midnight — returns `true` for the new day.
- `daysBetween(d, d)` — returns `0`.
- `daysBetween` across a DST boundary — may return a value off by one if implemented as raw millisecond division.
- `addDays(date, 0)` — returns a date equal (in milliseconds) to the input.
- `addDays` with a very large positive or negative `days` value — no overflow protection expected; behavior follows `Calendar.add` semantics (handles large values correctly by rolling over years).
- `startOfDay` on a date already at midnight — returns a `Date` equal to the input (same millisecond value).
- `isBefore(date, date)` where both refer to the same instant — returns `false` (not strictly before).
- `toIso8601` with a date at midnight UTC — output depends on JVM default timezone; may show `"T00:00:00"` or a different hour if the default timezone is not UTC.

## Quirks (preserve exactly unless user decides otherwise)

- **`SimpleDateFormat` is not thread-safe.** If the implementation creates a new `SimpleDateFormat` per call (static factory pattern), this is safe. If it uses a static shared instance, it is a latent concurrency bug. The migration must preserve call-by-call safety regardless of the old approach.
- **Lenient parsing by default.** `SimpleDateFormat` is lenient: invalid dates like month `13` or day `32` silently overflow. If callers rely on this behavior, strict parsing in the new API would be a breaking change.
- **Millisecond-based `daysBetween` ignores DST.** If implemented as `(end.getTime() - start.getTime()) / 86_400_000`, transitions through DST spring-forward/fall-back can produce an off-by-one. This quirk should be preserved unless the user explicitly opts into DST-correct behavior.
- **Default JVM timezone dependency.** `isToday`, `startOfDay`, `addDays`, and `toIso8601` all implicitly depend on `TimeZone.getDefault()`. The Kotlin migration must replicate this or accept a timezone parameter — the user must decide.
- **`toIso8601` timezone format unknown.** Without seeing the implementation, it is unclear whether the output includes a timezone offset (`+05:00`), a `Z` suffix (UTC only), or no offset at all. This detail matters for any downstream parser and must be verified against the actual implementation.
- **`null` handling.** Standard `java.util.Date` APIs throw `NullPointerException` on null input; `SimpleDateFormat.parse` may return `null` on empty input in some JVM versions. The existing callers may rely on NPE semantics or may guard against null upstream.

## Out of Scope

- Thread-safety improvements (e.g., replacing per-call `SimpleDateFormat` with a thread-safe formatter) — these are improvements, not behavioral migrations; flag to user before making.
- Strict date parsing (rejecting lenient overflow dates) — would break callers that rely on `SimpleDateFormat` leniency.
- Adding timezone parameters to methods currently using the default timezone — API change; requires user sign-off.
- Changing the return type of `parseDate` from `Date` to a Kotlin `LocalDate`/`Instant` — is an API-breaking change if callers exist; evaluate caller impact first.
