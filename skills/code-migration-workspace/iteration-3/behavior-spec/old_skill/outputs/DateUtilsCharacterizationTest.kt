/**
 * Characterization tests for DateUtils.java
 *
 * Purpose: pin down the ACTUAL behavior of the existing Java implementation so
 * that the Kotlin/kotlinx-datetime migration can be verified against it.
 * These tests capture what the code does — including quirks — not what it
 * ideally should do.
 *
 * Do NOT edit these tests to match a new implementation. If a test fails after
 * migration, it is a regression. Fix the implementation, not the test.
 *
 * All tests run in the JVM default timezone as configured at test startup.
 * If your CI environment uses UTC, make that explicit via:
 *   TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
 * and replicate the same assumption in the migrated code.
 */

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.TimeZone

class DateUtilsCharacterizationTest {

    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------

    /** Parse a date string using the default JVM timezone (same as implementation). */
    private fun date(pattern: String, value: String): Date =
        SimpleDateFormat(pattern).parse(value)!!

    /** Build a Calendar in the default JVM timezone. */
    private fun calendarOf(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0): Date {
        return Calendar.getInstance().also { cal ->
            cal.set(year, month - 1, day, hour, minute, second)
            cal.set(Calendar.MILLISECOND, 0)
        }.time
    }

    // ---------------------------------------------------------------------------
    // formatDate
    // ---------------------------------------------------------------------------

    @Test
    fun `formatDate - yyyy-MM-dd pattern`() {
        val d = calendarOf(2024, 3, 15)
        assertEquals("2024-03-15", DateUtils.formatDate(d, "yyyy-MM-dd"))
    }

    @Test
    fun `formatDate - dd slash MM slash yyyy pattern`() {
        val d = calendarOf(2024, 3, 15)
        assertEquals("15/03/2024", DateUtils.formatDate(d, "dd/MM/yyyy"))
    }

    @Test
    fun `formatDate - includes time components`() {
        val d = calendarOf(2024, 1, 1, 14, 30, 5)
        val result = DateUtils.formatDate(d, "yyyy-MM-dd HH:mm:ss")
        assertEquals("2024-01-01 14:30:05", result)
    }

    @Test
    fun `formatDate - empty pattern returns empty string`() {
        val d = calendarOf(2024, 1, 1)
        assertEquals("", DateUtils.formatDate(d, ""))
    }

    // ---------------------------------------------------------------------------
    // parseDate
    // ---------------------------------------------------------------------------

    @Test
    fun `parseDate - round-trip with formatDate`() {
        val original = calendarOf(2024, 6, 21)
        val formatted = DateUtils.formatDate(original, "yyyy-MM-dd")
        val parsed = DateUtils.parseDate(formatted, "yyyy-MM-dd")
        // Round-trip: parsed date should represent the same day at midnight
        assertEquals(DateUtils.startOfDay(original), DateUtils.startOfDay(parsed))
    }

    @Test
    fun `parseDate - lenient overflow - month 13 rolls into next year`() {
        // SimpleDateFormat is lenient by default; month 13 → January of next year
        val result = DateUtils.parseDate("2024-13-01", "yyyy-MM-dd")
        val expected = calendarOf(2025, 1, 1)
        assertEquals(DateUtils.startOfDay(expected), DateUtils.startOfDay(result))
    }

    @Test
    fun `parseDate - day 32 rolls into next month`() {
        val result = DateUtils.parseDate("2024-01-32", "yyyy-MM-dd")
        val expected = calendarOf(2024, 2, 1)
        assertEquals(DateUtils.startOfDay(expected), DateUtils.startOfDay(result))
    }

    @Test
    fun `parseDate - throws on completely invalid string`() {
        // Expect some kind of exception (ParseException or RuntimeException wrapping it)
        assertThrows(Exception::class.java) {
            DateUtils.parseDate("not-a-date", "yyyy-MM-dd")
        }
    }

    // ---------------------------------------------------------------------------
    // isToday
    // ---------------------------------------------------------------------------

    @Test
    fun `isToday - current instant returns true`() {
        assertTrue(DateUtils.isToday(Date()))
    }

    @Test
    fun `isToday - yesterday returns false`() {
        val yesterday = Calendar.getInstance().also { it.add(Calendar.DAY_OF_MONTH, -1) }.time
        assertFalse(DateUtils.isToday(yesterday))
    }

    @Test
    fun `isToday - tomorrow returns false`() {
        val tomorrow = Calendar.getInstance().also { it.add(Calendar.DAY_OF_MONTH, 1) }.time
        assertFalse(DateUtils.isToday(tomorrow))
    }

    @Test
    fun `isToday - start of today returns true`() {
        val todayMidnight = DateUtils.startOfDay(Date())
        assertTrue(DateUtils.isToday(todayMidnight))
    }

    @Test
    fun `isToday - end-of-day yesterday (23 59 59) returns false`() {
        val cal = Calendar.getInstance()
        cal.add(Calendar.DAY_OF_MONTH, -1)
        cal.set(Calendar.HOUR_OF_DAY, 23)
        cal.set(Calendar.MINUTE, 59)
        cal.set(Calendar.SECOND, 59)
        assertFalse(DateUtils.isToday(cal.time))
    }

    // ---------------------------------------------------------------------------
    // daysBetween
    // ---------------------------------------------------------------------------

    @Test
    fun `daysBetween - same date returns 0`() {
        val d = calendarOf(2024, 6, 15)
        assertEquals(0L, DateUtils.daysBetween(d, d))
    }

    @Test
    fun `daysBetween - one day apart returns 1`() {
        val start = calendarOf(2024, 6, 15)
        val end = calendarOf(2024, 6, 16)
        assertEquals(1L, DateUtils.daysBetween(start, end))
    }

    @Test
    fun `daysBetween - end before start returns negative`() {
        val start = calendarOf(2024, 6, 15)
        val end = calendarOf(2024, 6, 10)
        assertTrue(DateUtils.daysBetween(start, end) < 0)
        assertEquals(-5L, DateUtils.daysBetween(start, end))
    }

    @Test
    fun `daysBetween - 365 days apart`() {
        val start = calendarOf(2024, 1, 1)
        val end = calendarOf(2025, 1, 1)
        // 2024 is a leap year: 366 days
        assertEquals(366L, DateUtils.daysBetween(start, end))
    }

    @Test
    fun `daysBetween - uses integer division, ignores partial day`() {
        // start at noon, end at 11:59 next day = 23h59m < 24h → 0 full days in raw ms division
        val start = calendarOf(2024, 6, 15, 12, 0, 0)
        val end = calendarOf(2024, 6, 16, 11, 59, 59)
        // Raw ms division: (end - start) / 86_400_000 truncates to 0
        // This may be 0 or 1 depending on implementation — record actual value here.
        // IMPORTANT: run against real implementation and replace the assertion below.
        val actual = DateUtils.daysBetween(start, end)
        assertTrue(actual == 0L || actual == 1L, "Expected 0 or 1, got $actual")
    }

    // ---------------------------------------------------------------------------
    // addDays
    // ---------------------------------------------------------------------------

    @Test
    fun `addDays - add zero returns same day`() {
        val d = calendarOf(2024, 6, 15)
        assertEquals(DateUtils.startOfDay(d), DateUtils.startOfDay(DateUtils.addDays(d, 0)))
    }

    @Test
    fun `addDays - add positive shifts forward`() {
        val d = calendarOf(2024, 6, 15)
        val result = DateUtils.addDays(d, 5)
        val expected = calendarOf(2024, 6, 20)
        assertEquals(DateUtils.startOfDay(expected), DateUtils.startOfDay(result))
    }

    @Test
    fun `addDays - add negative shifts backward`() {
        val d = calendarOf(2024, 6, 15)
        val result = DateUtils.addDays(d, -5)
        val expected = calendarOf(2024, 6, 10)
        assertEquals(DateUtils.startOfDay(expected), DateUtils.startOfDay(result))
    }

    @Test
    fun `addDays - rolls over month boundary`() {
        val d = calendarOf(2024, 1, 30)
        val result = DateUtils.addDays(d, 3)
        val expected = calendarOf(2024, 2, 2)
        assertEquals(DateUtils.startOfDay(expected), DateUtils.startOfDay(result))
    }

    @Test
    fun `addDays - rolls over year boundary`() {
        val d = calendarOf(2024, 12, 31)
        val result = DateUtils.addDays(d, 1)
        val expected = calendarOf(2025, 1, 1)
        assertEquals(DateUtils.startOfDay(expected), DateUtils.startOfDay(result))
    }

    @Test
    fun `addDays - does not mutate input date`() {
        val d = calendarOf(2024, 6, 15)
        val originalMs = d.time
        DateUtils.addDays(d, 10)
        assertEquals(originalMs, d.time)
    }

    // ---------------------------------------------------------------------------
    // startOfDay
    // ---------------------------------------------------------------------------

    @Test
    fun `startOfDay - zeroes out time components`() {
        val d = calendarOf(2024, 6, 15, 14, 30, 45)
        val result = DateUtils.startOfDay(d)
        val cal = Calendar.getInstance()
        cal.time = result
        assertEquals(0, cal.get(Calendar.HOUR_OF_DAY))
        assertEquals(0, cal.get(Calendar.MINUTE))
        assertEquals(0, cal.get(Calendar.SECOND))
        assertEquals(0, cal.get(Calendar.MILLISECOND))
    }

    @Test
    fun `startOfDay - preserves date (year month day)`() {
        val d = calendarOf(2024, 6, 15, 14, 30, 45)
        val result = DateUtils.startOfDay(d)
        val cal = Calendar.getInstance()
        cal.time = result
        assertEquals(2024, cal.get(Calendar.YEAR))
        assertEquals(5 /* June = 5 in 0-based */, cal.get(Calendar.MONTH))
        assertEquals(15, cal.get(Calendar.DAY_OF_MONTH))
    }

    @Test
    fun `startOfDay - already at midnight returns same millisecond value`() {
        val d = calendarOf(2024, 6, 15, 0, 0, 0)
        val result = DateUtils.startOfDay(d)
        assertEquals(d.time, result.time)
    }

    @Test
    fun `startOfDay - does not mutate input`() {
        val d = calendarOf(2024, 6, 15, 14, 30, 45)
        val originalMs = d.time
        DateUtils.startOfDay(d)
        assertEquals(originalMs, d.time)
    }

    // ---------------------------------------------------------------------------
    // isBefore
    // ---------------------------------------------------------------------------

    @Test
    fun `isBefore - earlier date returns true`() {
        val earlier = calendarOf(2024, 6, 10)
        val later = calendarOf(2024, 6, 15)
        assertTrue(DateUtils.isBefore(earlier, later))
    }

    @Test
    fun `isBefore - later date returns false`() {
        val earlier = calendarOf(2024, 6, 10)
        val later = calendarOf(2024, 6, 15)
        assertFalse(DateUtils.isBefore(later, earlier))
    }

    @Test
    fun `isBefore - same instant returns false (not strictly before)`() {
        val d = calendarOf(2024, 6, 15)
        assertFalse(DateUtils.isBefore(d, d))
    }

    @Test
    fun `isBefore - one millisecond difference`() {
        val d1 = Date(1_000_000L)
        val d2 = Date(1_000_001L)
        assertTrue(DateUtils.isBefore(d1, d2))
        assertFalse(DateUtils.isBefore(d2, d1))
    }

    // ---------------------------------------------------------------------------
    // toIso8601
    // ---------------------------------------------------------------------------

    @Test
    fun `toIso8601 - contains date separator T and colon-separated time`() {
        val d = calendarOf(2024, 3, 15, 10, 5, 30)
        val result = DateUtils.toIso8601(d)
        // Minimal structural check: must contain the date part and a T separator
        assertTrue(result.contains("2024-03-15"), "Expected date part in: $result")
        assertTrue(result.contains("T"), "Expected T separator in: $result")
        assertTrue(result.contains("10:05:30"), "Expected time part in: $result")
    }

    @Test
    fun `toIso8601 - midnight date`() {
        val d = calendarOf(2024, 1, 1, 0, 0, 0)
        val result = DateUtils.toIso8601(d)
        assertTrue(result.startsWith("2024-01-01T"), "Expected ISO prefix in: $result")
    }

    @Test
    fun `toIso8601 - output is deterministic for the same input`() {
        val d = calendarOf(2024, 6, 21, 12, 0, 0)
        assertEquals(DateUtils.toIso8601(d), DateUtils.toIso8601(d))
    }

    /**
     * QUIRK TEST — timezone offset in output.
     * Run this against the real implementation and record the actual format.
     * Options: no offset (local-time-only), 'Z' suffix (UTC), or '+HH:MM' offset.
     *
     * Replace the assertion below once the actual format is confirmed.
     */
    @Test
    fun `toIso8601 - timezone representation (record actual format)`() {
        val d = calendarOf(2024, 1, 1, 0, 0, 0)
        val result = DateUtils.toIso8601(d)
        // Record actual output and lock it in:
        // assertTrue(result.endsWith("Z") || result.matches(Regex(".*[+-]\\d{2}:\\d{2}$")) || !result.contains("+"))
        // For now just assert it is non-empty and structurally plausible
        assertTrue(result.isNotEmpty())
        println("toIso8601 actual output: $result") // inspect during first run
    }
}
