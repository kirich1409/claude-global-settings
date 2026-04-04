/**
 * Characterization tests for DateUtils.java
 *
 * Purpose: snapshot the ACTUAL behavior of the Java implementation before migrating
 * to kotlin.time + kotlinx-datetime. These tests must all be green before Phase 3
 * (Migrate) begins. They pin down what the new Kotlin implementation must preserve.
 *
 * DO NOT modify these tests to match new behavior during the migration.
 * If a test fails after migration, it is a regression — fix the implementation.
 *
 * Framework: JUnit 5 (kotlin test + junit-jupiter)
 * Run with: ./gradlew :module:test
 */

import org.junit.jupiter.api.Test
import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.BeforeEach
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Calendar
import java.util.TimeZone
import java.util.Locale

class DateUtilsCharacterizationTest {

    // ---------------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------------

    /** Build a Date from calendar fields in the JVM default timezone. */
    private fun date(year: Int, month: Int, day: Int, hour: Int = 0, min: Int = 0, sec: Int = 0): Date {
        return Calendar.getInstance().apply {
            set(year, month - 1, day, hour, min, sec)
            set(Calendar.MILLISECOND, 0)
        }.time
    }

    /** Parse a date string using the given pattern (helper, not the class under test). */
    private fun parse(str: String, pattern: String): Date {
        return SimpleDateFormat(pattern, Locale.US).parse(str)!!
    }

    // ---------------------------------------------------------------------------
    // formatDate
    // ---------------------------------------------------------------------------

    @Test
    fun `formatDate - formats date with yyyy-MM-dd pattern`() {
        val d = date(2024, 6, 15)
        val result = DateUtils.formatDate(d, "yyyy-MM-dd")
        assertEquals("2024-06-15", result)
    }

    @Test
    fun `formatDate - formats date with dd_MM_yyyy pattern`() {
        val d = date(2024, 1, 5)
        val result = DateUtils.formatDate(d, "dd/MM/yyyy")
        assertEquals("05/01/2024", result)
    }

    @Test
    fun `formatDate - includes time components when pattern contains HH mm ss`() {
        val d = date(2024, 3, 10, 14, 30, 45)
        val result = DateUtils.formatDate(d, "yyyy-MM-dd HH:mm:ss")
        assertEquals("2024-03-10 14:30:45", result)
    }

    @Test
    fun `formatDate - returns empty string for empty pattern`() {
        val d = date(2024, 6, 15)
        // SimpleDateFormat("") produces "" for any date — preserve this quirk
        val result = DateUtils.formatDate(d, "")
        assertEquals("", result)
    }

    // ---------------------------------------------------------------------------
    // parseDate
    // ---------------------------------------------------------------------------

    @Test
    fun `parseDate - parses a valid date string`() {
        val result = DateUtils.parseDate("2024-06-15", "yyyy-MM-dd")
        val cal = Calendar.getInstance().apply { time = result }
        assertEquals(2024, cal.get(Calendar.YEAR))
        assertEquals(5 /* June = 5 */, cal.get(Calendar.MONTH))
        assertEquals(15, cal.get(Calendar.DAY_OF_MONTH))
    }

    @Test
    fun `parseDate - parses a date with time`() {
        val result = DateUtils.parseDate("2024-03-10 14:30:45", "yyyy-MM-dd HH:mm:ss")
        val cal = Calendar.getInstance().apply { time = result }
        assertEquals(14, cal.get(Calendar.HOUR_OF_DAY))
        assertEquals(30, cal.get(Calendar.MINUTE))
        assertEquals(45, cal.get(Calendar.SECOND))
    }

    @Test
    fun `parseDate - roundtrip formatDate then parseDate returns equivalent date`() {
        val original = date(2024, 11, 20, 9, 15, 0)
        val pattern = "yyyy-MM-dd HH:mm:ss"
        val formatted = DateUtils.formatDate(original, pattern)
        val parsed = DateUtils.parseDate(formatted, pattern)
        assertEquals(original, parsed)
    }

    @Test
    fun `parseDate - throws on malformed input`() {
        // SimpleDateFormat.parse() throws ParseException on mismatch.
        // The Java class may wrap it — capture the actual exception type here
        // by running the original and recording it. Then assert the same type post-migration.
        assertThrows(Exception::class.java) {
            DateUtils.parseDate("not-a-date", "yyyy-MM-dd")
        }
    }

    @Test
    fun `parseDate - throws on empty string`() {
        assertThrows(Exception::class.java) {
            DateUtils.parseDate("", "yyyy-MM-dd")
        }
    }

    // ---------------------------------------------------------------------------
    // isToday
    // ---------------------------------------------------------------------------

    @Test
    fun `isToday - returns true for current moment`() {
        val now = Date()
        assertTrue(DateUtils.isToday(now))
    }

    @Test
    fun `isToday - returns true for midnight of today`() {
        val midnight = Calendar.getInstance().apply {
            time = Date()
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.time
        assertTrue(DateUtils.isToday(midnight))
    }

    @Test
    fun `isToday - returns true for end of today (23 59 59)`() {
        val endOfDay = Calendar.getInstance().apply {
            time = Date()
            set(Calendar.HOUR_OF_DAY, 23)
            set(Calendar.MINUTE, 59)
            set(Calendar.SECOND, 59)
            set(Calendar.MILLISECOND, 999)
        }.time
        assertTrue(DateUtils.isToday(endOfDay))
    }

    @Test
    fun `isToday - returns false for yesterday`() {
        val yesterday = Calendar.getInstance().apply {
            time = Date()
            add(Calendar.DAY_OF_YEAR, -1)
        }.time
        assertFalse(DateUtils.isToday(yesterday))
    }

    @Test
    fun `isToday - returns false for tomorrow`() {
        val tomorrow = Calendar.getInstance().apply {
            time = Date()
            add(Calendar.DAY_OF_YEAR, 1)
        }.time
        assertFalse(DateUtils.isToday(tomorrow))
    }

    @Test
    fun `isToday - returns false for a date one year ago`() {
        val oneYearAgo = Calendar.getInstance().apply {
            time = Date()
            add(Calendar.YEAR, -1)
        }.time
        assertFalse(DateUtils.isToday(oneYearAgo))
    }

    // ---------------------------------------------------------------------------
    // daysBetween
    // ---------------------------------------------------------------------------

    @Test
    fun `daysBetween - same date returns 0`() {
        val d = date(2024, 3, 15)
        assertEquals(0L, DateUtils.daysBetween(d, d))
    }

    @Test
    fun `daysBetween - one day apart returns 1`() {
        val start = date(2024, 3, 15)
        val end   = date(2024, 3, 16)
        assertEquals(1L, DateUtils.daysBetween(start, end))
    }

    @Test
    fun `daysBetween - 30 days apart returns 30`() {
        val start = date(2024, 1, 1)
        val end   = date(2024, 1, 31)
        assertEquals(30L, DateUtils.daysBetween(start, end))
    }

    @Test
    fun `daysBetween - crossing year boundary`() {
        val start = date(2023, 12, 31)
        val end   = date(2024, 1, 1)
        assertEquals(1L, DateUtils.daysBetween(start, end))
    }

    @Test
    fun `daysBetween - end before start returns negative`() {
        val start = date(2024, 3, 16)
        val end   = date(2024, 3, 15)
        assertTrue(DateUtils.daysBetween(start, end) < 0L)
    }

    @Test
    fun `daysBetween - leap year Feb 28 to Mar 1 is 2 days`() {
        // 2024 is a leap year; Feb 29 exists
        val start = date(2024, 2, 28)
        val end   = date(2024, 3, 1)
        assertEquals(2L, DateUtils.daysBetween(start, end))
    }

    // ---------------------------------------------------------------------------
    // addDays
    // ---------------------------------------------------------------------------

    @Test
    fun `addDays - adding 0 days returns equivalent date`() {
        val d = date(2024, 6, 15)
        val result = DateUtils.addDays(d, 0)
        assertEquals(d, result)
    }

    @Test
    fun `addDays - adding 1 day advances by one calendar day`() {
        val d      = date(2024, 6, 15)
        val result = DateUtils.addDays(d, 1)
        val cal    = Calendar.getInstance().apply { time = result }
        assertEquals(16, cal.get(Calendar.DAY_OF_MONTH))
        assertEquals(5 /* June */, cal.get(Calendar.MONTH))
        assertEquals(2024, cal.get(Calendar.YEAR))
    }

    @Test
    fun `addDays - adding negative days subtracts`() {
        val d      = date(2024, 6, 15)
        val result = DateUtils.addDays(d, -1)
        val cal    = Calendar.getInstance().apply { time = result }
        assertEquals(14, cal.get(Calendar.DAY_OF_MONTH))
    }

    @Test
    fun `addDays - does not mutate the input date`() {
        val original   = date(2024, 6, 15)
        val originalMs = original.time
        DateUtils.addDays(original, 5)
        assertEquals(originalMs, original.time, "addDays must not mutate the input Date")
    }

    @Test
    fun `addDays - crossing month boundary`() {
        val d      = date(2024, 1, 30)
        val result = DateUtils.addDays(d, 3)
        val cal    = Calendar.getInstance().apply { time = result }
        assertEquals(2, cal.get(Calendar.DAY_OF_MONTH))
        assertEquals(1 /* February */, cal.get(Calendar.MONTH))
    }

    @Test
    fun `addDays - crossing year boundary`() {
        val d      = date(2024, 12, 30)
        val result = DateUtils.addDays(d, 3)
        val cal    = Calendar.getInstance().apply { time = result }
        assertEquals(2, cal.get(Calendar.DAY_OF_MONTH))
        assertEquals(0 /* January */, cal.get(Calendar.MONTH))
        assertEquals(2025, cal.get(Calendar.YEAR))
    }

    // ---------------------------------------------------------------------------
    // startOfDay
    // ---------------------------------------------------------------------------

    @Test
    fun `startOfDay - time components are zeroed out`() {
        val d      = date(2024, 6, 15, 14, 30, 45)
        val result = DateUtils.startOfDay(d)
        val cal    = Calendar.getInstance().apply { time = result }
        assertEquals(0, cal.get(Calendar.HOUR_OF_DAY))
        assertEquals(0, cal.get(Calendar.MINUTE))
        assertEquals(0, cal.get(Calendar.SECOND))
        assertEquals(0, cal.get(Calendar.MILLISECOND))
    }

    @Test
    fun `startOfDay - calendar day is preserved`() {
        val d      = date(2024, 6, 15, 23, 59, 59)
        val result = DateUtils.startOfDay(d)
        val cal    = Calendar.getInstance().apply { time = result }
        assertEquals(2024, cal.get(Calendar.YEAR))
        assertEquals(5 /* June */, cal.get(Calendar.MONTH))
        assertEquals(15, cal.get(Calendar.DAY_OF_MONTH))
    }

    @Test
    fun `startOfDay - already at midnight returns equivalent midnight`() {
        val d      = date(2024, 6, 15, 0, 0, 0)
        val result = DateUtils.startOfDay(d)
        val cal    = Calendar.getInstance().apply { time = result }
        assertEquals(0, cal.get(Calendar.HOUR_OF_DAY))
        assertEquals(0, cal.get(Calendar.MINUTE))
        assertEquals(0, cal.get(Calendar.SECOND))
        assertEquals(0, cal.get(Calendar.MILLISECOND))
    }

    @Test
    fun `startOfDay - does not mutate the input date`() {
        val d          = date(2024, 6, 15, 10, 30, 0)
        val originalMs = d.time
        DateUtils.startOfDay(d)
        assertEquals(originalMs, d.time, "startOfDay must not mutate the input Date")
    }

    // ---------------------------------------------------------------------------
    // isBefore
    // ---------------------------------------------------------------------------

    @Test
    fun `isBefore - earlier date is before later date`() {
        val earlier = date(2024, 3, 10)
        val later   = date(2024, 3, 15)
        assertTrue(DateUtils.isBefore(earlier, later))
    }

    @Test
    fun `isBefore - later date is not before earlier date`() {
        val earlier = date(2024, 3, 10)
        val later   = date(2024, 3, 15)
        assertFalse(DateUtils.isBefore(later, earlier))
    }

    @Test
    fun `isBefore - equal dates return false (strictly before)`() {
        val d = date(2024, 3, 10)
        assertFalse(DateUtils.isBefore(d, d))
    }

    @Test
    fun `isBefore - one millisecond apart`() {
        val base  = Date(1_000_000L)
        val later = Date(1_000_001L)
        assertTrue(DateUtils.isBefore(base, later))
        assertFalse(DateUtils.isBefore(later, base))
    }

    // ---------------------------------------------------------------------------
    // toIso8601
    // ---------------------------------------------------------------------------

    @Test
    fun `toIso8601 - output contains date separators in correct positions`() {
        val d      = date(2024, 6, 15, 10, 30, 0)
        val result = DateUtils.toIso8601(d)
        // Must contain 'T' separator between date and time portions
        assertTrue(result.contains('T'), "ISO 8601 output must contain 'T': $result")
        // Must start with 4-digit year
        assertTrue(result.matches(Regex("^\\d{4}-.*")), "Must start with year: $result")
    }

    @Test
    fun `toIso8601 - year month and day appear in output`() {
        val d      = date(2024, 6, 15)
        val result = DateUtils.toIso8601(d)
        assertTrue(result.contains("2024"), "Year must appear in ISO output: $result")
        assertTrue(result.contains("06"), "Month must appear as two digits: $result")
        assertTrue(result.contains("15"), "Day must appear in ISO output: $result")
    }

    @Test
    fun `toIso8601 - epoch date produces a non-empty string`() {
        val epoch  = Date(0L)
        val result = DateUtils.toIso8601(epoch)
        assertTrue(result.isNotEmpty(), "toIso8601 must not return empty string for epoch")
    }

    @Test
    fun `toIso8601 - snapshot exact format for a known date`() {
        // Record the ACTUAL output from the Java implementation for a fixed date.
        // This test captures the exact format quirk (with or without timezone offset).
        // Run this test against the Java source first and hard-code the result below.
        //
        // INSTRUCTION: replace REPLACE_WITH_ACTUAL_OUTPUT with the real output from the
        // Java DateUtils before committing this test file.
        //
        val d      = date(2024, 1, 15, 10, 30, 0)
        val result = DateUtils.toIso8601(d)
        // Acceptable patterns (inspect actual output and keep only the matching assertion):
        //   "2024-01-15T10:30:00"         ← no timezone
        //   "2024-01-15T10:30:00+05:00"   ← with offset
        //   "2024-01-15T10:30:00Z"        ← UTC
        // TODO: run original Java and capture exact output, then assert it here:
        // assertEquals("REPLACE_WITH_ACTUAL_OUTPUT", result)
        assertTrue(result.startsWith("2024-01-15T"), "Snapshot format mismatch: $result")
    }
}
