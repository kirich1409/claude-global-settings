package com.example.utils

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar
import java.util.Date
import java.util.TimeZone

/**
 * Characterization tests for DateUtils.
 *
 * These tests pin the *current* behavior of DateUtils — including quirks —
 * so that the migration to kotlinx-datetime can be verified against this baseline.
 *
 * DO NOT modify these tests to match new behavior. If the new implementation
 * diverges from an assertion here, that is a regression to investigate.
 * Only remove or change a test if the user has explicitly approved changing that behavior.
 *
 * See behavior-spec.md for the full behavioral contract and quirk documentation.
 */
class DateUtilsTest {

    // -------------------------------------------------------------------------
    // Helpers
    // -------------------------------------------------------------------------

    /** Build a Date at a specific local calendar date (device default timezone), time at noon. */
    private fun localDate(year: Int, month: Int, day: Int): Date {
        return Calendar.getInstance().apply {
            set(Calendar.YEAR, year)
            set(Calendar.MONTH, month - 1) // Calendar months are 0-based
            set(Calendar.DAY_OF_MONTH, day)
            set(Calendar.HOUR_OF_DAY, 12)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.time
    }

    /** Build a Date at exact UTC milliseconds. */
    private fun utcMillis(millis: Long): Date = Date(millis)

    // -------------------------------------------------------------------------
    // formatDate
    // -------------------------------------------------------------------------

    @Test
    fun `formatDate returns yyyy-MM-dd for a normal date`() {
        val date = localDate(2024, 3, 5)
        val result = DateUtils.formatDate(date)
        assertEquals("2024-03-05", result)
    }

    @Test
    fun `formatDate zero-pads month and day`() {
        val date = localDate(2024, 1, 7)
        val result = DateUtils.formatDate(date)
        assertEquals("2024-01-07", result)
    }

    @Test
    fun `formatDate handles year boundary`() {
        val date = localDate(2000, 12, 31)
        assertEquals("2000-12-31", DateUtils.formatDate(date))
    }

    @Test
    fun `formatDate handles leap day`() {
        val date = localDate(2024, 2, 29)
        assertEquals("2024-02-29", DateUtils.formatDate(date))
    }

    @Test
    fun `formatDate output length is always 10`() {
        val date = localDate(2024, 11, 9)
        assertEquals(10, DateUtils.formatDate(date).length)
    }

    // -------------------------------------------------------------------------
    // parseDate
    // -------------------------------------------------------------------------

    @Test
    fun `parseDate returns correct date for valid yyyy-MM-dd string`() {
        val date = DateUtils.parseDate("2024-03-05")
        assertNotNull(date)
        val cal = Calendar.getInstance().apply { time = date }
        assertEquals(2024, cal.get(Calendar.YEAR))
        assertEquals(2, cal.get(Calendar.MONTH)) // 0-based
        assertEquals(5, cal.get(Calendar.DAY_OF_MONTH))
    }

    @Test
    fun `parseDate round-trips with formatDate`() {
        val original = localDate(2024, 7, 15)
        val formatted = DateUtils.formatDate(original)
        val parsed = DateUtils.parseDate(formatted)
        assertEquals(formatted, DateUtils.formatDate(parsed))
    }

    /**
     * Quirk: lenient parsing silently rolls over day 32 of January to February 1.
     * This is the behavior of SimpleDateFormat in lenient mode (the default).
     * kotlinx-datetime is strict by default — migration must preserve this if callers rely on it.
     */
    @Test
    fun `parseDate lenient mode rolls over day 32 to next month`() {
        val date = DateUtils.parseDate("2024-01-32")
        val cal = Calendar.getInstance().apply { time = date }
        assertEquals(2024, cal.get(Calendar.YEAR))
        assertEquals(Calendar.FEBRUARY, cal.get(Calendar.MONTH))
        assertEquals(1, cal.get(Calendar.DAY_OF_MONTH))
    }

    /**
     * Quirk: lenient parsing rolls month 13 to January of the next year.
     */
    @Test
    fun `parseDate lenient mode rolls over month 13 to January next year`() {
        val date = DateUtils.parseDate("2024-13-01")
        val cal = Calendar.getInstance().apply { time = date }
        assertEquals(2025, cal.get(Calendar.YEAR))
        assertEquals(Calendar.JANUARY, cal.get(Calendar.MONTH))
        assertEquals(1, cal.get(Calendar.DAY_OF_MONTH))
    }

    /**
     * Quirk: Feb 29 in a non-leap year rolls to March 1 in lenient mode.
     */
    @Test
    fun `parseDate lenient mode rolls Feb 29 in non-leap year to March 1`() {
        val date = DateUtils.parseDate("2023-02-29") // 2023 is not a leap year
        val cal = Calendar.getInstance().apply { time = date }
        assertEquals(2023, cal.get(Calendar.YEAR))
        assertEquals(Calendar.MARCH, cal.get(Calendar.MONTH))
        assertEquals(1, cal.get(Calendar.DAY_OF_MONTH))
    }

    @Test(expected = Exception::class)
    fun `parseDate throws on empty string`() {
        DateUtils.parseDate("")
    }

    @Test(expected = Exception::class)
    fun `parseDate throws on non-date string`() {
        DateUtils.parseDate("not-a-date")
    }

    // -------------------------------------------------------------------------
    // isToday
    // -------------------------------------------------------------------------

    @Test
    fun `isToday returns true for current date`() {
        val now = Date()
        assertTrue(DateUtils.isToday(now))
    }

    @Test
    fun `isToday returns false for yesterday`() {
        val yesterday = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_MONTH, -1)
        }.time
        assertFalse(DateUtils.isToday(yesterday))
    }

    @Test
    fun `isToday returns false for tomorrow`() {
        val tomorrow = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_MONTH, 1)
        }.time
        assertFalse(DateUtils.isToday(tomorrow))
    }

    @Test
    fun `isToday returns true for start of today`() {
        val startOfToday = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.time
        assertTrue(DateUtils.isToday(startOfToday))
    }

    @Test
    fun `isToday returns true for end of today`() {
        val endOfToday = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 23)
            set(Calendar.MINUTE, 59)
            set(Calendar.SECOND, 59)
            set(Calendar.MILLISECOND, 999)
        }.time
        assertTrue(DateUtils.isToday(endOfToday))
    }

    // -------------------------------------------------------------------------
    // daysBetween
    // -------------------------------------------------------------------------

    @Test
    fun `daysBetween returns 0 for same date`() {
        val date = localDate(2024, 6, 15)
        assertEquals(0, DateUtils.daysBetween(date, date))
    }

    @Test
    fun `daysBetween returns 1 for consecutive days`() {
        val from = localDate(2024, 6, 15)
        val to = localDate(2024, 6, 16)
        assertEquals(1, DateUtils.daysBetween(from, to))
    }

    @Test
    fun `daysBetween returns 30 for a month`() {
        val from = localDate(2024, 1, 1)
        val to = localDate(2024, 1, 31)
        assertEquals(30, DateUtils.daysBetween(from, to))
    }

    @Test
    fun `daysBetween returns 365 for a non-leap year`() {
        val from = localDate(2023, 1, 1)
        val to = localDate(2024, 1, 1)
        assertEquals(365, DateUtils.daysBetween(from, to))
    }

    @Test
    fun `daysBetween returns 366 for a leap year`() {
        val from = localDate(2024, 1, 1)
        val to = localDate(2025, 1, 1)
        assertEquals(366, DateUtils.daysBetween(from, to))
    }

    @Test
    fun `daysBetween returns negative when from is after to`() {
        val from = localDate(2024, 6, 16)
        val to = localDate(2024, 6, 15)
        assertEquals(-1, DateUtils.daysBetween(from, to))
    }

    /**
     * Quirk: daysBetween uses millisecond division, not calendar-aware days.
     * Times that are less than 86400000ms apart but cross midnight count as 0 days.
     * This is a known limitation of the millisecond-math approach.
     */
    @Test
    fun `daysBetween returns 0 when timestamps are less than 24h apart even across midnight`() {
        // 23:00 on day 1 → 22:59 on day 2 = 23h59m apart = 0 full days in ms-math
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 23)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val from = cal.time

        cal.add(Calendar.MINUTE, 23 * 60 + 59) // +23h59m
        val to = cal.time

        assertEquals(0, DateUtils.daysBetween(from, to))
    }

    // -------------------------------------------------------------------------
    // getWeekday
    // -------------------------------------------------------------------------

    @Test
    fun `getWeekday returns Monday for a known Monday`() {
        // 2024-03-04 is a Monday
        val date = localDate(2024, 3, 4)
        assertEquals("Monday", DateUtils.getWeekday(date))
    }

    @Test
    fun `getWeekday returns Sunday for a known Sunday`() {
        // 2024-03-03 is a Sunday
        val date = localDate(2024, 3, 3)
        assertEquals("Sunday", DateUtils.getWeekday(date))
    }

    @Test
    fun `getWeekday returns all seven days correctly`() {
        // Week starting 2024-03-04 (Monday)
        val expectedDays = listOf("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday")
        val cal = Calendar.getInstance().apply {
            set(2024, Calendar.MARCH, 4, 12, 0, 0)
            set(Calendar.MILLISECOND, 0)
        }
        for (expected in expectedDays) {
            assertEquals(expected, DateUtils.getWeekday(cal.time))
            cal.add(Calendar.DAY_OF_MONTH, 1)
        }
    }

    /**
     * Quirk: always returns English names regardless of device locale.
     * This must be preserved in migration (use Locale.ENGLISH or equivalent).
     */
    @Test
    fun `getWeekday always returns English name regardless of locale`() {
        val savedLocale = java.util.Locale.getDefault()
        try {
            java.util.Locale.setDefault(java.util.Locale.FRENCH)
            val date = localDate(2024, 3, 4) // Monday
            assertEquals("Monday", DateUtils.getWeekday(date))
        } finally {
            java.util.Locale.setDefault(savedLocale)
        }
    }

    // -------------------------------------------------------------------------
    // toTimestamp
    // -------------------------------------------------------------------------

    @Test
    fun `toTimestamp returns date time millis`() {
        val millis = 1_700_000_000_000L
        val date = Date(millis)
        assertEquals(millis, DateUtils.toTimestamp(date))
    }

    @Test
    fun `toTimestamp returns 0 for Unix epoch`() {
        assertEquals(0L, DateUtils.toTimestamp(Date(0L)))
    }

    @Test
    fun `toTimestamp returns negative millis for pre-epoch dates`() {
        val preEpoch = Date(-86_400_000L) // 1 day before epoch
        assertEquals(-86_400_000L, DateUtils.toTimestamp(preEpoch))
    }

    // -------------------------------------------------------------------------
    // fromTimestamp
    // -------------------------------------------------------------------------

    @Test
    fun `fromTimestamp creates date with correct millis`() {
        val millis = 1_700_000_000_000L
        val date = DateUtils.fromTimestamp(millis)
        assertEquals(millis, date.time)
    }

    @Test
    fun `fromTimestamp of 0 returns Unix epoch`() {
        assertEquals(0L, DateUtils.fromTimestamp(0L).time)
    }

    @Test
    fun `fromTimestamp handles negative millis (pre-epoch)`() {
        val millis = -86_400_000L
        assertEquals(millis, DateUtils.fromTimestamp(millis).time)
    }

    @Test
    fun `toTimestamp and fromTimestamp are symmetric`() {
        val original = Date()
        val roundTripped = DateUtils.fromTimestamp(DateUtils.toTimestamp(original))
        assertEquals(original.time, roundTripped.time)
    }

    // -------------------------------------------------------------------------
    // formatRelative
    // -------------------------------------------------------------------------

    @Test
    fun `formatRelative returns today for current date`() {
        assertEquals("today", DateUtils.formatRelative(Date()))
    }

    @Test
    fun `formatRelative returns yesterday for yesterday`() {
        val yesterday = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 12)
            add(Calendar.DAY_OF_MONTH, -1)
        }.time
        assertEquals("yesterday", DateUtils.formatRelative(yesterday))
    }

    @Test
    fun `formatRelative returns X days ago for 2 days ago`() {
        val twoDaysAgo = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 12)
            add(Calendar.DAY_OF_MONTH, -2)
        }.time
        assertEquals("2 days ago", DateUtils.formatRelative(twoDaysAgo))
    }

    @Test
    fun `formatRelative returns X days ago for 30 days ago`() {
        val thirtyDaysAgo = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 12)
            add(Calendar.DAY_OF_MONTH, -30)
        }.time
        assertEquals("30 days ago", DateUtils.formatRelative(thirtyDaysAgo))
    }

    /**
     * Quirk: future dates produce a negative day count in the "X days ago" format.
     * There is no special handling for future dates — this is almost certainly a bug,
     * but it is preserved here as current behavior.
     * User must explicitly approve changing this behavior during migration.
     */
    @Test
    fun `formatRelative returns negative days ago for future date`() {
        val tomorrow = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 12)
            add(Calendar.DAY_OF_MONTH, 1)
        }.time
        assertEquals("-1 days ago", DateUtils.formatRelative(tomorrow))
    }

    @Test
    fun `formatRelative output is lowercase`() {
        val result = DateUtils.formatRelative(Date())
        assertEquals(result, result.lowercase())
    }
}
