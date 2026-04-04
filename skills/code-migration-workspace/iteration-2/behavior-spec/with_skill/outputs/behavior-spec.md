# Behavior Specification: DateUtils
FROM: Java (`java.util.Date`, `java.text.SimpleDateFormat`, `java.util.Calendar`) → TO: Kotlin (`kotlin.time`, `kotlinx-datetime`)

---

## Public Interface

| Method | Inputs | Output / Side Effect | Notes |
|---|---|---|---|
| `formatDate(date: Date)` | `java.util.Date` — any non-null Date | `String` in `"yyyy-MM-dd"` format | Format is fixed; not locale-sensitive |
| `parseDate(str: String)` | `String` matching `"yyyy-MM-dd"`; also accepts out-of-range values due to lenient mode | `java.util.Date` | Lenient: `"2024-01-32"` → Feb 1, 2024. Throws `ParseException` (unchecked via RuntimeException) on non-date strings. |
| `isToday(date: Date)` | `java.util.Date` — any non-null Date | `Boolean` | Uses device default timezone (Calendar.getInstance()). A timestamp at 23:59 in one timezone may not be "today" in another. |
| `daysBetween(from: Date, to: Date)` | Two non-null `java.util.Date` values | `Int` — number of calendar days between (to − from) | Computed via millisecond arithmetic: `(to.time - from.time) / 86_400_000`. Does NOT account for DST transitions — a day with a DST gap counts as 23 hours, producing off-by-one errors in edge cases. Returns negative Int if `from` is after `to`. |
| `getWeekday(date: Date)` | `java.util.Date` — any non-null Date | `String` — English weekday name ("Monday" … "Sunday") | Uses `SimpleDateFormat("EEEE", Locale.ENGLISH)` or equivalent. Result is always English regardless of device locale. |
| `toTimestamp(date: Date)` | `java.util.Date` — any non-null Date | `Long` — milliseconds since Unix epoch | Equivalent to `date.time`. |
| `fromTimestamp(millis: Long)` | `Long` — milliseconds since Unix epoch | `java.util.Date` | Equivalent to `Date(millis)`. No range validation. Negative values produce pre-epoch dates. |
| `formatRelative(date: Date)` | `java.util.Date` — any non-null Date | `String` — `"today"`, `"yesterday"`, or `"X days ago"` | Delegates to `daysBetween` and `isToday`. "today" if 0 days; "yesterday" if 1 day; "X days ago" for X >= 2. Future dates produce negative X and format as "-1 days ago", "-2 days ago", etc. (no special future handling). |

---

## Normal Behaviors

- `formatDate` always produces a zero-padded, ISO-8601-style date string (`"2024-03-05"`, not `"2024-3-5"`).
- `parseDate` in lenient mode silently rolls over out-of-range values: month 13 → month 1 of next year; day 32 → day 1 or 2 of next month.
- `isToday` compares year, month, and day fields in the **device default timezone** — not UTC.
- `daysBetween` truncates to whole days by integer division of milliseconds. Time-of-day components in `from` and `to` affect the result: `daysBetween(23:59, 00:01 next day)` = 0 days (< 86400000 ms apart).
- `getWeekday` always returns English names ("Monday", not "Lunes" or locale equivalent), pinned via `Locale.ENGLISH`.
- `toTimestamp` / `fromTimestamp` are symmetric: `fromTimestamp(toTimestamp(date)).time == date.time`.
- `formatRelative` uses lowercase output: `"today"`, `"yesterday"`, `"3 days ago"`.

---

## Edge Cases

- `formatDate` / `getWeekday` / `isToday` with a `Date` at exactly midnight UTC: result depends on device timezone — may shift the visible date by ±1 day.
- `parseDate("")`: throws `ParseException` (wrapped as RuntimeException).
- `parseDate("not-a-date")`: throws `ParseException` (wrapped as RuntimeException).
- `parseDate("2024-02-29")` on a non-leap year: lenient mode rolls to March 1.
- `daysBetween(d, d)`: returns 0.
- `daysBetween(to, from)` where from is later: returns negative Int.
- `fromTimestamp(0L)`: returns `Date` at Unix epoch (1970-01-01T00:00:00Z).
- `fromTimestamp(Long.MIN_VALUE)`: no validation — behavior is implementation-defined (likely garbage date).
- `formatRelative` with a future date (e.g., tomorrow): returns `"-1 days ago"` — no special handling for future dates.
- `formatRelative` with today: returns `"today"`.
- `formatRelative` with yesterday: returns `"yesterday"`.

---

## Quirks (preserve exactly unless user decides otherwise)

1. **Lenient parsing in `parseDate`** — `SimpleDateFormat` in lenient mode silently accepts invalid dates like `"2024-01-32"` and rolls them over. This is almost certainly an accidental behavior (lenient is the default), but it may be relied upon by callers. **Must be discussed with user before migration** — kotlinx-datetime's `LocalDate.parse` is strict by default and will throw on these inputs.

2. **DST-blind millisecond math in `daysBetween`** — dividing `(to.time - from.time)` by 86_400_000 ignores DST clock changes. On a day that is 23 hours long (spring-forward), timestamps 23 hours apart will produce 0 days. kotlinx-datetime's `until(ChronoUnit.DAYS)` handles DST correctly via calendar-aware arithmetic. **This behavioral difference must be explicitly acknowledged by the user.**

3. **`formatRelative` with future dates returns negative string** — `"-1 days ago"` for tomorrow is almost certainly a bug, not a feature. But it must be preserved unless the user opts to fix it.

4. **`isToday` uses system default timezone** — behavior changes if the user changes their device timezone mid-session. kotlinx-datetime uses `TimeZone.currentSystemDefault()` which behaves identically, so this quirk is naturally preserved.

5. **`getWeekday` pinned to `Locale.ENGLISH`** — explicit, intentional; must be preserved in migration.

---

## Out of Scope

- Changing `parseDate` from lenient to strict mode (user must decide — see Quirks #1).
- Fixing the `formatRelative` future-date negative string behavior (user must decide — see Quirks #3).
- Fixing the DST edge case in `daysBetween` (user must decide — see Quirks #2).
- Changing the public API signatures from `java.util.Date` to kotlinx-datetime types (that is the migration goal, handled in Phase 3; these characterization tests pin the *old* behavior).
