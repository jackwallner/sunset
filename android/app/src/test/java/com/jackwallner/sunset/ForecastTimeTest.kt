package com.jackwallner.sunset

import com.jackwallner.sunset.data.ForecastService
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Open-Meteo writes every time of a point on one clock, the UTC offset in force
 * when the request was made (`utc_offset_seconds`), for the whole window. A
 * daylight saving change inside the window does not move the labels (24 per
 * day, always), and with `timezone=auto` each of the three points gets its own
 * clock, so an ocean point comes back as an `Etc/GMT` zone. Same cases as
 * `SunsetTests/ForecastTimeTests.swift`; fixtures follow live responses
 * (2026-10-31).
 */
class ForecastTimeTest {
    private val la = ZoneId.of("America/Los_Angeles")

    private fun point(
        zone: String,
        offset: Int?,
        days: List<String>,
        sunrise: List<String>,
        sunset: List<String>,
        low: List<Double?>? = null,
    ): String {
        val times = days.flatMap { day -> (0 until 24).map { "\"${day}T${"%02d".format(it)}:00\"" } }
        fun list(values: List<Double?>) = values.joinToString(",") { it?.toString() ?: "null" }
        fun fill(value: Double) = list(List(times.size) { value })
        fun quoted(values: List<String>) = values.joinToString(",") { "\"$it\"" }
        val offsetField = offset?.let { "\"utc_offset_seconds\":$it," } ?: ""
        return """{"timezone":"$zone",$offsetField"hourly":{"time":[${times.joinToString(",")}],
            "cloud_cover_low":[${low?.let(::list) ?: fill(0.0)}],"cloud_cover_mid":[${fill(20.0)}],"cloud_cover_high":[${fill(45.0)}],
            "relative_humidity_2m":[${fill(50.0)}],"visibility":[${fill(24_000.0)}],"precipitation_probability":[${fill(0.0)}]},
            "daily":{"sunrise":[${quoted(sunrise)}],"sunset":[${quoted(sunset)}]}}"""
    }

    private fun parse(here: String, west: String = here, east: String = here) =
        ForecastService.parse("[$here,$west,$east]", 45.63, -122.52)

    /**
     * 2027-03-14 02:00 PST jumps to 03:00 PDT. A request made on the 13th is
     * labelled on the -8 h clock, so the 14th still has a 02:00 row, a local
     * time that does not exist in Los Angeles. The whole forecast used to be
     * refused for the week before the change (and on the day itself).
     */
    @Test fun theWeekBeforeSpringForwardStillLoads() {
        val here = point(
            "America/Los_Angeles", -28_800, listOf("2027-03-13", "2027-03-14"),
            sunrise = listOf("2027-03-13T06:26", "2027-03-14T06:24"),
            sunset = listOf("2027-03-13T18:13", "2027-03-14T18:14"),
        )
        val forecast = parse(here)

        assertEquals(2, forecast.days.size)
        assertEquals("America/Los_Angeles", forecast.timeZoneId)
        // 18:14 on the -8 h clock is 02:14 UTC: 7:14 PM once the clocks moved.
        val sunset = forecast.days[1].sunset.time
        assertEquals(Instant.parse("2027-03-15T02:14:00Z"), sunset)
        assertEquals(19, sunset.atZone(la).hour)
        assertEquals(7, forecast.days[1].sunrise.time.atZone(la).hour)
    }

    /**
     * 2026-11-01 02:00 PDT falls back to 01:00 PST. A request made on the 31st
     * is labelled on the -7 h clock for all of it, so the 1st's 17:56 is
     * 16:56 in Los Angeles. It used to be read as 17:56 PST, an hour late.
     */
    @Test fun theWeekBeforeFallBackKeepsTheRealMoments() {
        val here = point(
            "America/Los_Angeles", -25_200, listOf("2026-10-31", "2026-11-01"),
            sunrise = listOf("2026-10-31T07:48", "2026-11-01T07:50"),
            sunset = listOf("2026-10-31T17:58", "2026-11-01T17:56"),
        )
        val forecast = parse(here)

        assertEquals(2, forecast.days.size)
        val before = forecast.days[0]
        assertEquals(Instant.parse("2026-11-01T00:58:00Z"), before.sunset.time)
        assertEquals(17, before.sunset.time.atZone(la).hour)

        val after = forecast.days[1]
        assertEquals(Instant.parse("2026-11-02T00:56:00Z"), after.sunset.time)
        assertEquals(16, after.sunset.time.atZone(la).hour)
        assertEquals(Instant.parse("2026-11-01T14:50:00Z"), after.sunrise.time)
        assertEquals(6, after.sunrise.time.atZone(la).hour)
        assertEquals(Instant.parse("2026-11-02T00:46:00Z"), after.sunset.bestWindowStart)
    }

    /**
     * An ocean point is resolved to an `Etc/GMT` zone, one hour behind Los
     * Angeles in daylight saving time (San Diego sunsets, Honolulu, Lisbon,
     * Cape Town and every east-coast sunrise do the same). Its rows must be
     * matched by moment, not by position.
     */
    @Test fun aSunwardPointOnAnotherClockIsReadAtTheSameMoment() {
        val westLow = MutableList<Double?>(48) { 0.0 }
        // West labels 17:00 and 18:00 on the -8 h clock are 18:00 and 19:00 PDT.
        westLow[17] = 90.0
        westLow[18] = 90.0
        val days = listOf("2026-10-08", "2026-10-09")
        val here = point(
            "America/Los_Angeles", -25_200, days,
            sunrise = listOf("2026-10-08T07:18", "2026-10-09T07:19"),
            sunset = listOf("2026-10-08T18:30", "2026-10-09T18:28"),
        )
        val west = point(
            "Etc/GMT+8", -28_800, days,
            sunrise = listOf("2026-10-08T06:18", "2026-10-09T06:19"),
            sunset = listOf("2026-10-08T17:30", "2026-10-09T17:28"),
            low = westLow,
        )
        val forecast = parse(here, west = west)

        assertEquals(90.0, forecast.days[0].sunset.conditions.cloudLowTowardSun, 0.01)
        assertEquals(0.0, forecast.days[0].sunset.conditions.cloudLow, 0.01)
    }

    /** The east point one hour ahead (Denver beside Los Angeles) for a sunrise. */
    @Test fun anEastPointAheadOfTheUserIsReadAtTheSameMoment() {
        val eastLow = MutableList<Double?>(48) { 0.0 }
        // East labels 08:00 and 09:00 on the -6 h clock are 07:00 and 08:00 PDT.
        eastLow[8] = 80.0
        eastLow[9] = 80.0
        val days = listOf("2026-10-08", "2026-10-09")
        val here = point(
            "America/Los_Angeles", -25_200, days,
            sunrise = listOf("2026-10-08T07:18", "2026-10-09T07:19"),
            sunset = listOf("2026-10-08T18:30", "2026-10-09T18:28"),
        )
        val east = point(
            "America/Denver", -21_600, days,
            sunrise = listOf("2026-10-08T08:18", "2026-10-09T08:19"),
            sunset = listOf("2026-10-08T19:30", "2026-10-09T19:28"),
            low = eastLow,
        )
        val forecast = parse(here, east = east)

        assertEquals(80.0, forecast.days[0].sunrise.conditions.cloudLowTowardSun, 0.01)
    }

    /**
     * Clocks half an hour apart blend the sunward rows at the moment instead
     * of snapping to one. St. John's keeps UTC-2:30 in summer; the Atlantic
     * east of it is `Etc/GMT+3`.
     */
    @Test fun rowsAHalfHourApartAreBlendedAtTheMoment() {
        val ramp = List<Double?>(48) { (it % 24) * 4.0 }
        val days = listOf("2026-10-08", "2026-10-09")
        val here = point(
            "America/St_Johns", -9_000, days,
            sunrise = listOf("2026-10-08T07:18", "2026-10-09T07:19"),
            sunset = listOf("2026-10-08T18:40", "2026-10-09T18:28"),
        )
        val east = point(
            "Etc/GMT+3", -10_800, days,
            sunrise = listOf("2026-10-08T06:48", "2026-10-09T06:49"),
            sunset = listOf("2026-10-08T18:10", "2026-10-09T17:58"),
            low = ramp,
        )
        val forecast = parse(here, east = east)

        // 07:18 on the -2:30 clock is 09:48 UTC, label 06:48 on the -3:00
        // clock: rows 06 (24) and 07 (28), 0.8 of the way between them.
        assertEquals(27.2, forecast.days[0].sunrise.conditions.cloudLowTowardSun, 0.01)
    }

    /** Older responses and cached fixtures carry no offset: the named zone still reads them. */
    @Test fun withoutAnOffsetTheNamedZoneReadsTheLabels() {
        val here = point(
            "America/Los_Angeles", null, listOf("2026-10-08", "2026-10-09"),
            sunrise = listOf("2026-10-08T07:18", "2026-10-09T07:19"),
            sunset = listOf("2026-10-08T18:30", "2026-10-09T18:28"),
        )
        val forecast = parse(here)

        assertEquals(Instant.parse("2026-10-09T01:30:00Z"), forecast.days[0].sunset.time)
        assertEquals(Duration.ofMinutes(10), Duration.between(forecast.days[0].sunset.bestWindowStart, forecast.days[0].sunset.time))
    }
}
