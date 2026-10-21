package com.jackwallner.sunset

import com.jackwallner.sunset.data.ForecastService
import com.jackwallner.sunset.model.AlertPlanner
import com.jackwallner.sunset.model.SkyConditions
import com.jackwallner.sunset.model.SkyEvent
import com.jackwallner.sunset.model.SkyEventDetector
import com.jackwallner.sunset.model.SolarPosition
import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.model.SunShow
import com.jackwallner.sunset.model.SunsetDay
import com.jackwallner.sunset.model.SunsetForecast
import com.jackwallner.sunset.model.SunsetFormat
import com.jackwallner.sunset.model.SunsetScore
import com.jackwallner.sunset.model.SunsetScorer
import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

/** `SunsetScorerTests.swift`, line for line. */
class SunsetScorerTests {
    private fun sky(
        low: Double = 0.0, mid: Double = 0.0, high: Double = 0.0, west: Double? = null,
        humidity: Double = 45.0, visibility: Double = 30_000.0, rain: Double = 0.0,
    ) = SkyConditions(low, mid, high, west ?: low, humidity, visibility, rain)

    @Test fun cirrusOverClearHorizonIsEpic() {
        val score = SunsetScorer.score(sky(mid = 25.0, high = 50.0))
        assertTrue(score.total >= 85)
        assertEquals(SunsetScore.Grade.EPIC, score.grade)
        assertEquals(100, score.horizon)
    }

    @Test fun clearSkyIsPlainButNotDull() {
        val score = SunsetScorer.score(sky())
        assertTrue("clear sky scored ${score.total}", score.total in 35..49)
        assertEquals(SunsetScore.Grade.FAIR, score.grade)
        assertTrue(score.summary.contains("clear"))
    }

    @Test fun lowOvercastIsDull() {
        val score = SunsetScorer.score(sky(low = 100.0, mid = 60.0, high = 20.0, humidity = 90.0, visibility = 8_000.0))
        assertTrue(score.total < 30)
        assertEquals(SunsetScore.Grade.DULL, score.grade)
    }

    @Test fun lowCloudToTheWestBlocksEvenWithOpenSkyOverhead() {
        val open = SunsetScorer.score(sky(mid = 20.0, high = 50.0, west = 0.0))
        val blocked = SunsetScorer.score(sky(mid = 20.0, high = 50.0, west = 95.0))
        assertTrue(open.total - blocked.total > 30)
        assertTrue(blocked.summary.contains("west"))
    }

    @Test fun rainCutsTheScore() {
        val dry = SunsetScorer.score(sky(mid = 30.0, high = 50.0))
        val wet = SunsetScorer.score(sky(mid = 30.0, high = 50.0, rain = 80.0))
        assertTrue(wet.total < dry.total / 2 + 10)
        assertTrue(wet.summary.contains("Rain"))
    }

    @Test fun humidityAndHazeLowerClarity() {
        val crisp = SunsetScorer.score(sky(high = 45.0))
        val hazy = SunsetScorer.score(sky(high = 45.0, humidity = 95.0, visibility = 4_000.0))
        assertEquals(0, hazy.clarity)
        assertTrue(crisp.clarity > 85)
        assertTrue(crisp.total > hazy.total)
    }

    @Test fun scoresStayWithinRange() {
        for (low in 0..100 step 25) for (high in 0..100 step 25) {
            val score = SunsetScorer.score(sky(low = low.toDouble(), mid = 50.0, high = high.toDouble()))
            assertTrue(score.total in 0..100)
            score.factors.forEach { assertTrue("${it.name} was ${it.value}", it.value in 0..100) }
        }
    }

    @Test fun gradeBoundaries() {
        assertEquals(SunsetScore.Grade.DULL, SunsetScore.Grade.of(29))
        assertEquals(SunsetScore.Grade.FAIR, SunsetScore.Grade.of(30))
        assertEquals(SunsetScore.Grade.GOOD, SunsetScore.Grade.of(50))
        assertEquals(SunsetScore.Grade.GREAT, SunsetScore.Grade.of(70))
        assertEquals(SunsetScore.Grade.EPIC, SunsetScore.Grade.of(85))
    }

    @Test fun interpolationWeightsTowardTheLaterHour() {
        assertEquals(75.0, SunsetScorer.interpolate(sky(high = 0.0), sky(high = 100.0), 0.75).cloudHigh, 0.001)
        assertEquals(100.0, SunsetScorer.interpolate(sky(high = 0.0), sky(high = 100.0), 2.0).cloudHigh, 0.0)
    }

    @Test fun sunriseSummaryLooksEast() {
        val score = SunsetScorer.score(SkyConditions(0.0, 20.0, 50.0, 95.0, 50.0, 30_000.0, 0.0), SunEvent.SUNRISE)
        assertTrue(score.summary.contains("east"))
        assertTrue(score.summary.contains("first light"))
    }

    @Test fun rainSummaryNamesTheMoment() {
        val sky = SkyConditions(0.0, 0.0, 0.0, 0.0, 50.0, 30_000.0, 90.0)
        assertTrue(SunsetScorer.score(sky, SunEvent.SUNRISE).summary.contains("at sunrise"))
    }
}

/** `ForecastServiceTests.swift`, line for line. */
class ForecastServiceTests {
    private fun point(timezone: String, lows: List<Double?>, highs: List<Double?>, codes: List<Double?>? = null): String {
        val hours = (0 until 48).map { hour ->
            val day = if (hour < 24) "2026-10-08" else "2026-10-09"
            "\"${day}T${"%02d".format(hour % 24)}:00\""
        }
        fun list(values: List<Double?>) = values.joinToString(",") { it?.toString() ?: "null" }
        val codeList = codes?.let { ",\"weather_code\":[${list(it)}]" } ?: ""
        return """
        {"timezone":"$timezone","hourly":{"time":[${hours.joinToString(",")}],
        "cloud_cover_low":[${list(lows)}],"cloud_cover_mid":[${list(List(48) { 20.0 })}],
        "cloud_cover_high":[${list(highs)}],"relative_humidity_2m":[${list(List(48) { 50.0 })}],
        "visibility":[${list(List(48) { 24140.0 })}],"precipitation_probability":[${list(List(48) { 0.0 })}]$codeList},
        "daily":{"sunrise":["2026-10-08T07:18","2026-10-09T07:19"],"sunset":["2026-10-08T18:30","2026-10-09T18:28"]}}
        """
    }

    private val zero: List<Double?> get() = List(48) { 0.0 }

    @Test fun parsesThreePointsAndScoresEachShowAgainstItsOwnHorizon() {
        val highs = zero.toMutableList().apply { this[7] = 40.0; this[8] = 40.0; this[18] = 40.0; this[19] = 60.0 }
        val westLows = zero.toMutableList().apply { this[18] = 90.0; this[19] = 90.0 }
        val eastLows = zero.toMutableList().apply { this[7] = 70.0; this[8] = 70.0 }
        val json = "[${point("America/Los_Angeles", zero, highs)},${point("America/Los_Angeles", westLows, highs)},${point("America/Los_Angeles", eastLows, highs)}]"

        val forecast = ForecastService.parse(json, 45.63, -122.52, Instant.now())

        assertEquals(2, forecast.days.size)
        assertEquals("America/Los_Angeles", forecast.timeZoneId)
        val sunset = forecast.days[0].sunset
        assertEquals(SunEvent.SUNSET, sunset.event)
        assertEquals(50.0, sunset.conditions.cloudHigh, 0.01)
        assertEquals(90.0, sunset.conditions.cloudLowTowardSun, 0.01)
        assertEquals(0.0, sunset.conditions.cloudLow, 0.01)
        assertTrue(sunset.score.total < 45)

        val sunrise = forecast.days[0].sunrise
        assertEquals(SunEvent.SUNRISE, sunrise.event)
        assertEquals(70.0, sunrise.conditions.cloudLowTowardSun, 0.01)

        val zone = ZoneId.of("America/Los_Angeles")
        assertEquals(18, sunset.time.atZone(zone).hour)
        assertEquals(30, sunset.time.atZone(zone).minute)
        assertEquals(7, sunrise.time.atZone(zone).hour)
    }

    @Test fun missingValuesFallBackInsteadOfFailing() {
        val empty = List<Double?>(48) { null }
        val one = point("Europe/London", empty, empty)
        val forecast = ForecastService.parse("[$one,$one,$one]", 51.5, -0.1)
        assertEquals(0.0, forecast.days.first().sunset.conditions.cloudHigh, 0.0)
        assertEquals(emptyList<SkyEvent>(), forecast.skyEvents)
    }

    @Test fun thunderstormHoursBecomeOneEvent() {
        val codes = MutableList<Double?>(48) { 1.0 }.apply { this[15] = 95.0; this[16] = 95.0; this[17] = 96.0 }
        val here = point("America/Chicago", zero, zero, codes)
        val other = point("America/Chicago", zero, zero)
        val forecast = ForecastService.parse("[$here,$other,$other]", 41.9, -87.6)
        val storms = forecast.skyEvents.filter { it.kind == SkyEvent.Kind.THUNDERSTORM }
        assertEquals(1, storms.size)
        assertEquals(Duration.ofHours(3), Duration.between(storms.first().start, storms.first().end))
    }

    @Test fun fewerThanThreePointsIsRejected() {
        val one = point("Europe/London", zero, zero)
        for (body in listOf(one, "[$one,$one]")) {
            try {
                ForecastService.parse(body, 0.0, 0.0)
                fail("accepted $body")
            } catch (_: ForecastService.Failure) {
            }
        }
    }

    @Test fun offsetPointsMoveAboutEightyKilometres() {
        val west = ForecastService.westPoint(45.63, -122.52)
        assertEquals(45.63, west.first, 0.0)
        assertEquals(-123.55, west.second, 0.02)
        assertEquals(-121.49, ForecastService.eastPoint(45.63, -122.52).second, 0.02)
        assertTrue(ForecastService.westPoint(89.0, 0.0).second >= -3)
        assertTrue(ForecastService.westPoint(0.0, -179.9).second > 0)
        assertTrue(ForecastService.eastPoint(0.0, 179.9).second < 0)
    }

    @Test fun urlSendsRoundedCoordinatesAndAllThreePoints() {
        val url = ForecastService.url(45.63412, -122.52199, 8)
        assertTrue(url.contains("latitude=45.63,45.63,45.63"))
        assertTrue(url.contains("longitude=-122.52,-123.55,-121.49"))
        assertTrue(url.contains("cloud_cover_high"))
        assertTrue(url.contains("weather_code"))
        assertTrue(url.contains("forecast_days=8"))
    }

    @Test fun upcomingShowsSkipFinishedOnesAndRespectWatched() {
        val now = Instant.ofEpochSecond(1_000_000)
        fun show(event: SunEvent, offset: Long) =
            SunShow(event, now.plusSeconds(offset), SkyConditions.CLEAR, SunsetScorer.score(SkyConditions.CLEAR))
        val today = SunsetDay(show(SunEvent.SUNRISE, -10 * 3600), show(SunEvent.SUNSET, -3600))
        val tomorrow = SunsetDay(show(SunEvent.SUNRISE, 10 * 3600), show(SunEvent.SUNSET, 22 * 3600))
        val forecast = SunsetForecast(0.0, 0.0, null, "UTC", now, listOf(today, tomorrow), emptyList())
        assertEquals(tomorrow.sunrise, forecast.upcomingShows(now = now).first())
        assertEquals(tomorrow.sunset, forecast.upcomingShows(setOf(SunEvent.SUNSET), now).first())
        assertEquals(today.sunset, forecast.upcomingShows(setOf(SunEvent.SUNSET), now.minusSeconds(3600 + 20 * 60)).first())
        assertEquals(listOf(tomorrow), forecast.upcomingDays(now))
    }
}

/** `SkyEventAndAlertTests.swift`, line for line. */
class SkyEventAndAlertTests {
    private val zone = ZoneId.of("America/Los_Angeles")

    private fun date(hour: Int, minute: Int = 0, day: Int = 8): Instant =
        ZonedDateTime.of(2026, 10, day, hour, minute, 0, 0, zone).toInstant()

    @Before fun locale() {
        Locale.setDefault(Locale.US)
        SunsetFormat.use24Hour = false
    }

    @Test fun sunIsLowInLateAfternoonAndDownAtNight() {
        val afternoon = SolarPosition.elevation(date(17), 45.6, -122.5)
        val noon = SolarPosition.elevation(date(13), 45.6, -122.5)
        val night = SolarPosition.elevation(date(23), 45.6, -122.5)
        assertTrue("5 pm elevation $afternoon", afternoon in 2.0..20.0)
        assertTrue("noon elevation $noon", noon in 30.0..45.0)
        assertTrue(night < 0)
    }

    @Test fun showersUnderBrokenSkyWithLowSunAreARainbowChance() {
        val showers = SkyEventDetector.Hour(date(17), 80, 55.0, 0.6, 60.0, 20_000.0)
        assertEquals(listOf(SkyEvent.Kind.RAINBOW), SkyEventDetector.kinds(showers, 15.0))
        assertEquals(emptyList<SkyEvent.Kind>(), SkyEventDetector.kinds(showers, 50.0))
        assertEquals(emptyList<SkyEvent.Kind>(), SkyEventDetector.kinds(showers.copy(cloudCover = 100.0), 15.0))
        assertEquals(emptyList<SkyEvent.Kind>(), SkyEventDetector.kinds(showers.copy(precipitation = 0.0), 15.0))
    }

    @Test fun fogFromCodeOrVisibility() {
        val foggy = SkyEventDetector.Hour(date(6), 45, 100.0, 0.0, 0.0, 5_000.0)
        assertEquals(listOf(SkyEvent.Kind.FOG), SkyEventDetector.kinds(foggy, -5.0))
        val murky = SkyEventDetector.Hour(date(6), 3, 100.0, 0.0, 0.0, 400.0)
        assertEquals(listOf(SkyEvent.Kind.FOG), SkyEventDetector.kinds(murky, -5.0))
    }

    @Test fun separateRunsStaySeparate() {
        val hours = listOf(9, 10, 14).map { SkyEventDetector.Hour(date(it), 95, 90.0, 3.0, 80.0, 10_000.0) }
        val events = SkyEventDetector.detect(hours, 45.6, -122.5)
        assertEquals(listOf(SkyEvent.Kind.THUNDERSTORM, SkyEvent.Kind.THUNDERSTORM), events.map { it.kind })
        assertEquals(date(11), events[0].end)
    }

    private fun show(event: SunEvent, time: Instant, score: Int) =
        SunShow(event, time, SkyConditions.CLEAR, SunsetScorer.score(SkyConditions.CLEAR, event).copy(total = score))

    private fun forecast(events: List<SkyEvent> = emptyList()): SunsetForecast {
        val day = SunsetDay(show(SunEvent.SUNRISE, date(7, 18, day = 9), 80), show(SunEvent.SUNSET, date(18, 30), 75))
        val later = SunsetDay(show(SunEvent.SUNRISE, date(7, 19, day = 10), 40), show(SunEvent.SUNSET, date(18, 28, day = 9), 50))
        return SunsetForecast(45.6, -122.5, null, zone.id, date(9), listOf(day, later), events)
    }

    @Test fun freeShowAlertsUseThresholdAndSunriseArrivesTheEveningBefore() {
        val planned = AlertPlanner.plan(forecast(), SunEvent.entries.toSet(), 70, 45, emptySet(), date(9))
        assertEquals(listOf(date(17, 45), date(20)), planned.map { it.fireDate })
        assertTrue(planned[1].title.contains("sunrise tomorrow"))
    }

    @Test fun watchedFiltersShows() {
        assertEquals(1, AlertPlanner.plan(forecast(), setOf(SunEvent.SUNRISE), 70, 45, emptySet(), date(9)).size)
    }

    @Test fun skyEventsNeedTheirKindAndSkipQuietHours() {
        val storm = SkyEvent(SkyEvent.Kind.THUNDERSTORM, date(15), date(17))
        val overnightFog = SkyEvent(SkyEvent.Kind.FOG, date(5, day = 9), date(9, day = 9))
        val planned = AlertPlanner.plan(
            forecast(listOf(storm, overnightFog)), emptySet(), 70, 45,
            setOf(SkyEvent.Kind.THUNDERSTORM, SkyEvent.Kind.FOG), date(9),
        )
        assertEquals(listOf(date(14), date(20)), planned.map { it.fireDate })
        assertEquals(0, AlertPlanner.plan(forecast(listOf(storm)), emptySet(), 70, 45, setOf(SkyEvent.Kind.FOG), date(9)).size)
    }
}
