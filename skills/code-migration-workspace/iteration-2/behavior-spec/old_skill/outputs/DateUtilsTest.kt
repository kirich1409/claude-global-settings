package com.example.util

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.text.ParseException
import java.util.Calendar
import java.util.Date
import java.util.TimeZone

/**
 * Characterization tests for DateUtils.java.
 *
 * PURPOSE: These tests capture what DateUtils *actually does* — not what it ideally should do.
 * They form the behavioral snapshot that must remain GREEN throughout the migration.
 *
 * IMPORTANT: Run these against the original DateUtils.java BEFORE writing any migration code.
 * All tests must pass on the original implementation. Any test that fails on the original
 * is a broken snapshot — stop and discuss with the team before proceeding to Phase 3.
 *
 * DO NOT weaken or delete these tests during the migration. If a test fails after migration,
 * that is a regression — fix the new implementation, not the test.
 *
 * NOTE: Several tests depend on the device's default timezone (TimeZone.getDefault()).
 * The test suite pins behaviors relative to "today" using the same timezone the class uses.
 * Tests that would behave differently across timezones are marked with [TZ-SENSITIVE].
 */
class DateUtilsTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    /** Builds a Date at midnight of the given year/month/day in the default timezone. */
    private fun dateOf(year: Int, month: Int, day: Int): Date {
        val cal = Calendar.getInstance() // uses default timezone
        cal.set(year, month - 1, day, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.time
    }

    /** Builds a Date at a specific time in the default timezone. */
    private fun dateOf(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int): Date {
        val cal = Calendar.getInstance()
        cal.set(year, month - 1, day, hour, minute, second)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.time
    }

    /** Returns today's date as a Date at midnight in the default timezone. */
    private fun today(): Date {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.time
    }

    /** Returns yesterday's Date at midnight. */
    private fun yesterday(): Date {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, -1)
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.time
    }

    // ─────────────────────────────────────────────────────────────────────────
    // formatDate(date: Date): String
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    fun formatDate_knownDate_returnsIsoString() {
        // 2024-06-15 at noon in the default timezone
        val date = dateOf(2024, 6, 15, 12, 0, 0)
        assertEquals("2024-06-15", DateUtils.formatDate(date))
    }

    @Test
    fun formatDate_singleDigitMonthAndDay_zeroPadded() {
        val date = dateOf(2024, 1, 5, 6, 0, 0)
        assertEquals("2024-01-05", DateUtils.formatDate(date))
    }

    @Test
    fun formatDate_lastDayOfYear() {
        val date = dateOf(2023, 12, 31, 23, 59, 59)
        assertEquals("2023-12-31", DateUtils.formatDate(date))
    }

    @Test
    fun formatDate_firstDayOfYear() {
        val date = dateOf(2024, 1, 1, 0, 0, 0)
        assertEquals("2024-01-01", DateUtils.formatDate(date))
    }

    @Test
    fun formatDate_leapDay() {
        val date = dateOf(2024, 2, 29, 12, 0, 0)
        assertEquals("2024-02-29", DateUtils.formatDate(date))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // parseDate(str: String): Date
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    fun parseDate_validString_returnsMidnightInDefaultTimezone() {
        val result = DateUtils.parseDate("2024-06-15")
        assertNotNull(result)
        // Verify the calendar fields in the default timezone match
        val cal = Calendar.getInstance() // default tz
        cal.time = result
        assertEquals(2024, cal.get(Calendar.YEAR))
        assertEquals(6 - 1, cal.get(Calendar.MONTH)) // Calendar.MONTH is 0-based
        assertEquals(15, cal.get(Calendar.DAY_OF_MONTH))
        assertEquals(0, cal.get(Calendar.HOUR_OF_DAY))
        assertEquals(0, cal.get(Calendar.MINUTE))
        assertEquals(0, cal.get(Calendar.SECOND))
    }

    @Test
    fun parseDate_leapDay_parsesCorrectly() {
        val result = DateUtils.parseDate("2024-02-29")
        val cal = Calendar.getInstance()
        cal.time = result
        assertEquals(2024, cal.get(Calendar.YEAR))
        assertEquals(Calendar.FEBRUARY, cal.get(Calendar.MONTH))
        assertEquals(29, cal.get(Calendar.DAY_OF_MONTH))
    }

    /**
     * QUIRK: SimpleDateFormat in lenient mode rolls over out-of-range values.
     * "2024-02-30" does not exist; lenient mode silently advances to "2024-03-01".
     * This behavior MUST be preserved (or explicitly changed with user approval).
     * See behavior-spec.md — Quirks #1.
     */
    @Test
    fun parseDate_lenientRollover_invalidDay_rollsToNextMonth() {
        // Feb 30 does not exist in 2024. Lenient mode: rolls to March 1.
        val result = DateUtils.parseDate("2024-02-30")
        val cal = Calendar.getInstance()
        cal.time = result
        assertEquals(2024, cal.get(Calendar.YEAR))
        assertEquals(Calendar.MARCH, cal.get(Calendar.MONTH))
        assertEquals(1, cal.get(Calendar.DAY_OF_MONTH))
    }

    /**
     * QUIRK: Month 13 rolls over to the next year.
     * See behavior-spec.md — Quirks #1.
     */
    @Test
    fun parseDate_lenientRollover_invalidMonth_rollsToNextYear() {
        // Month 13 of 2024 → January 2025
        val result = DateUtils.parseDate("2024-13-01")
        val cal = Calendar.getInstance()
        cal.time = result
        assertEquals(2025, cal.get(Calendar.YEAR))
        assertEquals(Calendar.JANUARY, cal.get(Calendar.MONTH))
        assertEquals(1, cal.get(Calendar.DAY_OF_MONTH))
    }

    @Test(expected = Exception::class)
    fun parseDate_completelyInvalidString_throws() {
        // "not-a-date" cannot be parsed even in lenient mode — must throw.
        // The exact exception type (ParseException or a wrapper) is pinned here.
        // If the method returns null instead of throwing, this test will be updated
        // to assert null — but the behavior must be captured explicitly.
        DateUtils.parseDate("not-a-date")
    }

    @Test
    fun parseDate_roundtrip_withFormatDate() {
        val original = dateOf(2024, 8, 20, 12, 30, 0)
        val formatted = DateUtils.formatDate(original)
        val parsed = DateUtils.parseDate(formatted)
        // Parsed result should represent the same calendar date in the default timezone
        val calOriginal = Calendar.getInstance()
        calOriginal.time = original
        val calParsed = Calendar.getInstance()
        calParsed.time = parsed
        assertEquals(calOriginal.get(Calendar.YEAR), calParsed.get(Calendar.YEAR))
        assertEquals(calOriginal.get(Calendar.MONTH), calParsed.get(Calendar.MONTH))
        assertEquals(calOriginal.get(Calendar.DAY_OF_MONTH), calParsed.get(Calendar.DAY_OF_MONTH))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // isToday(date: Date): Boolean
    // [TZ-SENSITIVE]: depends on TimeZone.getDefault()
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    fun isToday_todayAtMidnight_returnsTrue() {
        assertTrue(DateUtils.isToday(today()))
    }

    @Test
    fun isToday_todayAtEndOfDay_returnsTrue() {
        val endOfDay = dateOf(
            Calendar.getInstance().get(Calendar.YEAR),
            Calendar.getInstance().get(Calendar.MONTH) + 1,
            Calendar.getInstance().get(Calendar.DAY_OF_MONTH),
            23, 59, 59
        )
        assertTrue(DateUtils.isToday(endOfDay))
    }

    @Test
    fun isToday_yesterday_returnsFalse() {
        assertFalse(DateUtils.isToday(yesterday()))
    }

    @Test
    fun isToday_tomorrow_returnsFalse() {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, 1)
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        assertFalse(DateUtils.isToday(cal.time))
    }

    @Test
    fun isToday_arbitraryPastDate_returnsFalse() {
        assertFalse(DateUtils.isToday(dateOf(2020, 1, 1)))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // daysBetween(from: Date, to: Date): Int
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    fun daysBetween_sameDate_returnsZero() {
        val date = dateOf(2024, 6, 15)
        assertEquals(0, DateUtils.daysBetween(date, date))
    }

    @Test
    fun daysBetween_oneDayApart_returnsOne() {
        val from = dateOf(2024, 6, 15)
        val to = dateOf(2024, 6, 16)
        assertEquals(1, DateUtils.daysBetween(from, to))
    }

    @Test
    fun daysBetween_reversed_returnsNegative() {
        val from = dateOf(2024, 6, 16)
        val to = dateOf(2024, 6, 15)
        assertEquals(-1, DateUtils.daysBetween(from, to))
    }

    @Test
    fun daysBetween_acrossMonthBoundary() {
        val from = dateOf(2024, 1, 28)
        val to = dateOf(2024, 2, 3)
        assertEquals(6, DateUtils.daysBetween(from, to))
    }

    @Test
    fun daysBetween_acrossYearBoundary() {
        val from = dateOf(2023, 12, 31)
        val to = dateOf(2024, 1, 2)
        assertEquals(2, DateUtils.daysBetween(from, to))
    }

    @Test
    fun daysBetween_timesWithinSameDayAreIgnored() {
        // Different times on the same day — must return 0, not 0 or 1 depending on time.
        val from = dateOf(2024, 6, 15, 1, 0, 0)
        val to = dateOf(2024, 6, 15, 23, 59, 59)
        assertEquals(0, DateUtils.daysBetween(from, to))
    }

    @Test
    fun daysBetween_acrossLeapDay() {
        val from = dateOf(2024, 2, 28)
        val to = dateOf(2024, 3, 1)
        // 2024 is a leap year: Feb 28 → Feb 29 → Mar 1 = 2 days
        assertEquals(2, DateUtils.daysBetween(from, to))
    }

    @Test
    fun daysBetween_largeRange() {
        val from = dateOf(2020, 1, 1)
        val to = dateOf(2024, 1, 1)
        // 2020 (366) + 2021 (365) + 2022 (365) + 2023 (365) = 1461 days
        assertEquals(1461, DateUtils.daysBetween(from, to))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // getWeekday(date: Date): String
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    fun getWeekday_knownMonday() {
        // 2024-01-01 is a Monday
        assertEquals("Monday", DateUtils.getWeekday(dateOf(2024, 1, 1)))
    }

    @Test
    fun getWeekday_knownTuesday() {
        // 2024-01-02 is a Tuesday
        assertEquals("Tuesday", DateUtils.getWeekday(dateOf(2024, 1, 2)))
    }

    @Test
    fun getWeekday_knownWednesday() {
        // 2024-01-03 is a Wednesday
        assertEquals("Wednesday", DateUtils.getWeekday(dateOf(2024, 1, 3)))
    }

    @Test
    fun getWeekday_knownThursday() {
        // 2024-01-04 is a Thursday
        assertEquals("Thursday", DateUtils.getWeekday(dateOf(2024, 1, 4)))
    }

    @Test
    fun getWeekday_knownFriday() {
        // 2024-01-05 is a Friday
        assertEquals("Friday", DateUtils.getWeekday(dateOf(2024, 1, 5)))
    }

    @Test
    fun getWeekday_knownSaturday() {
        // 2024-01-06 is a Saturday
        assertEquals("Saturday", DateUtils.getWeekday(dateOf(2024, 1, 6)))
    }

    @Test
    fun getWeekday_knownSunday() {
        // 2024-01-07 is a Sunday
        assertEquals("Sunday", DateUtils.getWeekday(dateOf(2024, 1, 7)))
    }

    @Test
    fun getWeekday_returnsCapitalizedEnglishName() {
        // Regardless of device locale, the name must be a full English weekday name
        val result = DateUtils.getWeekday(dateOf(2024, 1, 1))
        val validWeekdays = setOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
        assertTrue("Expected a valid English weekday name but got: $result", result in validWeekdays)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // toTimestamp(date: Date): Long
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    fun toTimestamp_epoch_returnsZero() {
        assertEquals(0L, DateUtils.toTimestamp(Date(0)))
    }

    @Test
    fun toTimestamp_knownDate_returnsCorrectMillis() {
        // 2024-01-01T00:00:00Z = 1704067200000 ms since epoch
        val date = Date(1704067200000L)
        assertEquals(1704067200000L, DateUtils.toTimestamp(date))
    }

    @Test
    fun toTimestamp_matchesDateGetTime() {
        val date = dateOf(2024, 6, 15, 12, 30, 0)
        assertEquals(date.time, DateUtils.toTimestamp(date))
    }

    @Test
    fun toTimestamp_negativeTimestamp() {
        // Date before epoch
        val date = Date(-1000L)
        assertEquals(-1000L, DateUtils.toTimestamp(date))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // fromTimestamp(millis: Long): Date
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    fun fromTimestamp_zero_returnsEpoch() {
        val result = DateUtils.fromTimestamp(0L)
        assertEquals(0L, result.time)
    }

    @Test
    fun fromTimestamp_knownMillis_returnsCorrectDate() {
        val millis = 1704067200000L // 2024-01-01T00:00:00Z
        val result = DateUtils.fromTimestamp(millis)
        assertEquals(millis, result.time)
    }

    @Test
    fun fromTimestamp_negativeMillis_returnsPreEpochDate() {
        val millis = -86400000L // 1969-12-31T00:00:00Z
        val result = DateUtils.fromTimestamp(millis)
        assertEquals(millis, result.time)
    }

    @Test
    fun fromTimestamp_roundtrip_withToTimestamp() {
        val original = dateOf(2024, 8, 20, 14, 0, 0)
        val millis = DateUtils.toTimestamp(original)
        val roundtripped = DateUtils.fromTimestamp(millis)
        assertEquals(original.time, roundtripped.time)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // formatRelative(date: Date): String
    // [TZ-SENSITIVE]: depends on TimeZone.getDefault() and current wall-clock time
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    fun formatRelative_today_returnsToday() {
        assertEquals("today", DateUtils.formatRelative(today()))
    }

    @Test
    fun formatRelative_todayAtDifferentTime_returnsToday() {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 12)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        assertEquals("today", DateUtils.formatRelative(cal.time))
    }

    @Test
    fun formatRelative_yesterday_returnsYesterday() {
        assertEquals("yesterday", DateUtils.formatRelative(yesterday()))
    }

    @Test
    fun formatRelative_twoDaysAgo_returnsTwoDaysAgo() {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, -2)
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        assertEquals("2 days ago", DateUtils.formatRelative(cal.time))
    }

    @Test
    fun formatRelative_sevenDaysAgo_returnsSevenDaysAgo() {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, -7)
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        assertEquals("7 days ago", DateUtils.formatRelative(cal.time))
    }

    @Test
    fun formatRelative_thirtyDaysAgo_returnsThirtyDaysAgo() {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, -30)
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        assertEquals("30 days ago", DateUtils.formatRelative(cal.time))
    }

    /**
     * QUIRK: Behavior for future dates is unspecified in the original description.
     * This test captures whatever the implementation actually returns.
     * The migration must preserve this exact output.
     *
     * Possible actual behaviors:
     * - Returns "-1 days ago" (if it uses raw daysBetween without clamping)
     * - Returns "today" (if future rounds to 0 days)
     * - Throws an exception
     * - Returns some other string
     *
     * When running against the real implementation, replace the TODO below with
     * the actual observed output and add the appropriate assertion.
     */
    @Test
    fun formatRelative_futureDate_characterizesActualBehavior() {
        val tomorrow = run {
            val cal = Calendar.getInstance()
            cal.add(Calendar.DAY_OF_YEAR, 1)
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            cal.time
        }
        // TODO: Run against the real implementation and pin the actual output.
        // Uncomment and fill in the expected value after observing actual behavior:
        // assertEquals("ACTUAL_OUTPUT_HERE", DateUtils.formatRelative(tomorrow))

        // For now: verify it does not crash (at minimum, behavior is defined)
        val result = DateUtils.formatRelative(tomorrow)
        assertNotNull(result)
        // Pin the result once observed — do not leave this open-ended after the snapshot run.
    }

    @Test
    fun formatRelative_calendarDayBoundary_notHourWindow() {
        // Yesterday at 23:58 — this is a calendar day before today, not "24 hours ago"
        // If today is 2024-06-15 at 01:00, yesterday at 23:58 is only ~1 hour ago
        // but it's a different calendar day — must return "yesterday", not "today"
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_YEAR, -1)
        cal.set(Calendar.HOUR_OF_DAY, 23)
        cal.set(Calendar.MINUTE, 58)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        assertEquals("yesterday", DateUtils.formatRelative(cal.time))
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Cross-method consistency
    // ─────────────────────────────────────────────────────────────────────────

    @Test
    fun formatAndParse_roundtrip_sameDayFields() {
        val original = dateOf(2024, 11, 30, 15, 45, 0)
        val formatted = DateUtils.formatDate(original)
        val parsed = DateUtils.parseDate(formatted)
        // formatDate strips time → re-parsed result is midnight; only date fields match
        val calOriginal = Calendar.getInstance()
        calOriginal.time = original
        val calParsed = Calendar.getInstance()
        calParsed.time = parsed
        assertEquals(calOriginal.get(Calendar.YEAR), calParsed.get(Calendar.YEAR))
        assertEquals(calOriginal.get(Calendar.MONTH), calParsed.get(Calendar.MONTH))
        assertEquals(calOriginal.get(Calendar.DAY_OF_MONTH), calParsed.get(Calendar.DAY_OF_MONTH))
    }

    @Test
    fun daysBetween_todayAndYesterday_isOne() {
        assertEquals(1, DateUtils.daysBetween(yesterday(), today()))
    }

    @Test
    fun isToday_andFormatRelative_agreeOnToday() {
        val date = today()
        assertTrue(DateUtils.isToday(date))
        assertEquals("today", DateUtils.formatRelative(date))
    }

    @Test
    fun isToday_andFormatRelative_agreeOnYesterday() {
        val date = yesterday()
        assertFalse(DateUtils.isToday(date))
        assertEquals("yesterday", DateUtils.formatRelative(date))
    }
}
