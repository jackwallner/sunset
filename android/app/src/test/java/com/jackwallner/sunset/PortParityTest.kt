package com.jackwallner.sunset

import com.jackwallner.sunset.data.ForecastService
import com.jackwallner.sunset.model.AlertPlanner
import com.jackwallner.sunset.model.DemoForecast
import com.jackwallner.sunset.model.SkyConditions
import com.jackwallner.sunset.model.SkyEvent
import com.jackwallner.sunset.model.SkyEventDetector
import com.jackwallner.sunset.model.SolarPosition
import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.model.SunShow
import com.jackwallner.sunset.model.SunsetFormat
import com.jackwallner.sunset.model.SunsetForecast
import com.jackwallner.sunset.model.SunsetScorer
import java.time.Instant
import java.time.ZoneId
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.BeforeClass
import org.junit.Test

/**
 * Compares the Kotlin port with what the real iOS sources compute
 * (`scripts/sync-android-parity.sh` compiles them into
 * `sunset-parity.json`): every scored sky, sun elevation, sky event rule,
 * request URL, parsed forecast, alert plan, copy helper and the demo week.
 */
class PortParityTest {
    companion object {
        private lateinit var fixture: JSONObject
        private val LA: ZoneId = ZoneId.of("America/Los_Angeles")

        @BeforeClass @JvmStatic fun load() {
            Locale.setDefault(Locale.US)
            SunsetFormat.use24Hour = false
            val text = PortParityTest::class.java.getResource("/sunset-parity.json")!!.readText()
            fixture = JSONObject(text)
        }

        /** macOS 13+ puts a narrow no-break space before AM/PM; compare the words. */
        private fun normal(text: String) = text.replace(' ', ' ').replace(' ', ' ')

        private fun instant(seconds: Double): Instant = Instant.ofEpochMilli(Math.round(seconds * 1000))
    }

    @Test fun everyScoredSkyMatchesIos() {
        val rows = fixture.getJSONArray("scores")
        val summaries = fixture.getJSONArray("summaries")
        assertEquals(5760, rows.length())
        for (i in 0 until rows.length()) {
            val r = rows.getJSONArray(i)
            val sky = SkyConditions(r.getDouble(0), r.getDouble(1), r.getDouble(2), r.getDouble(3), r.getDouble(4), r.getDouble(5), r.getDouble(6))
            val event = if (r.getInt(7) == 0) SunEvent.SUNRISE else SunEvent.SUNSET
            val score = SunsetScorer.score(sky, event)
            val expected = listOf(r.getInt(8), r.getInt(9), r.getInt(10), r.getInt(11), r.getInt(12), r.getInt(13))
            val actual = listOf(score.total, score.color, score.streaks, score.horizon, score.clarity, score.rainChance)
            assertEquals("row $i $sky $event", expected, actual)
            assertEquals("row $i summary", summaries.getString(r.getInt(14)), score.summary)
        }
        // Every summary sentence the scorer can write is reached by the grid.
        assertEquals(15, summaries.length())
    }

    @Test fun sunElevationMatchesIos() {
        val rows = fixture.getJSONArray("solar")
        assertEquals(320, rows.length())
        for (i in 0 until rows.length()) {
            val r = rows.getJSONArray(i)
            val elevation = SolarPosition.elevation(instant(r.getDouble(0)), r.getDouble(1), r.getDouble(2))
            assertEquals("row $i", r.getDouble(3), elevation, 1e-9)
        }
    }

    @Test fun skyEventRulesMatchIos() {
        val rows = fixture.getJSONArray("kinds")
        assertEquals(4212, rows.length())
        val order = listOf(SkyEvent.Kind.THUNDERSTORM, SkyEvent.Kind.RAINBOW, SkyEvent.Kind.FOG)
        var flagged = 0
        for (i in 0 until rows.length()) {
            val r = rows.getJSONArray(i)
            fun opt(index: Int) = r.getDouble(index).takeIf { it >= 0 }
            val hour = SkyEventDetector.Hour(Instant.EPOCH, r.getInt(0).takeIf { it >= 0 }, opt(1), opt(2), opt(3), opt(4))
            val found = SkyEventDetector.kinds(hour, r.getDouble(5))
            val mask = order.withIndex().sumOf { (bit, kind) -> if (kind in found) 1 shl bit else 0 }
            assertEquals("row $i", r.getInt(6), mask)
            if (mask != 0) flagged++
        }
        assertTrue("grid reaches events", flagged > 500)
    }

    @Test fun requestUrlsAndSunwardPointsMatchIos() {
        val rows = fixture.getJSONArray("urls")
        for (i in 0 until rows.length()) {
            val r = rows.getJSONObject(i)
            val lat = r.getDouble("latitude")
            val lon = r.getDouble("longitude")
            assertEquals(r.getString("url"), ForecastService.url(lat, lon, 8))
            val west = ForecastService.westPoint(lat, lon)
            val east = ForecastService.eastPoint(lat, lon)
            assertEquals(r.getJSONArray("west").getDouble(1), west.second, 0.0)
            assertEquals(r.getJSONArray("east").getDouble(1), east.second, 0.0)
        }
    }

    @Test fun parsedForecastsMatchIos() {
        val cases = fixture.getJSONArray("parse")
        for (c in 0 until cases.length()) {
            val case = cases.getJSONObject(c)
            val forecast = ForecastService.parse(case.getString("json"), case.getDouble("latitude"), case.getDouble("longitude"), instant(case.getDouble("now")))
            assertForecast(case.getJSONObject("forecast"), forecast)
        }
    }

    @Test fun alertPlansMatchIos() {
        val cases = fixture.getJSONArray("plans")
        val parsed = fixture.getJSONArray("parse").let { parse ->
            (0 until parse.length()).map { parse.getJSONObject(it) }.map {
                ForecastService.parse(it.getString("json"), it.getDouble("latitude"), it.getDouble("longitude"), instant(it.getDouble("now")))
            }
        }
        var alerts = 0
        for (i in 0 until cases.length()) {
            val case = cases.getJSONObject(i)
            val forecast = if (case.getString("forecast") == "la") parsed[0] else parsed[1]
            val planned = AlertPlanner.plan(
                forecast = forecast,
                watched = strings(case.getJSONArray("watched")).mapNotNull(SunEvent::from).toSet(),
                threshold = case.getInt("threshold"),
                leadMinutes = case.getInt("lead"),
                skyEventKinds = strings(case.getJSONArray("skyKinds")).mapNotNull(SkyEvent.Kind::from).toSet(),
                now = instant(case.getDouble("now")),
            )
            val expected = case.getJSONArray("planned")
            assertEquals("case $i count", expected.length(), planned.size)
            planned.forEachIndexed { index, alert ->
                val e = expected.getJSONObject(index)
                assertEquals("case $i id", e.getString("id"), alert.identifier)
                assertEquals("case $i fire", instant(e.getDouble("fire")), alert.fireDate)
                assertEquals("case $i title", e.getString("title"), alert.title)
                assertEquals("case $i body", normal(e.getString("body")), normal(alert.body))
                alerts++
            }
        }
        assertEquals(2743, alerts)
    }

    @Test fun copyHelpersMatchIos() {
        val now = java.time.ZonedDateTime.of(2026, 10, 8, 9, 0, 0, 0, LA).toInstant()
        val rows = fixture.getJSONArray("format")
        for (i in 0 until rows.length()) {
            val r = rows.getJSONObject(i)
            val time = instant(r.getDouble("time"))
            val event = SunEvent.from(r.getString("event"))!!
            val show = SunShow(event, time, SkyConditions.CLEAR, SunsetScorer.score(SkyConditions.CLEAR, event))
            assertEquals(r.getString("headline"), SunsetFormat.headline(show, LA, now))
            assertEquals(r.getString("relativeDay"), SunsetFormat.relativeDay(time, LA, now))
            assertEquals(r.getString("dayLabel"), SunsetFormat.dayLabel(time, LA, now))
            assertEquals(normal(r.getString("clock")), normal(SunsetFormat.time(time, LA)))
        }
        val minutes = fixture.getJSONArray("minutes")
        for (i in 0 until minutes.length()) {
            val m = minutes.getJSONObject(i)
            assertEquals(m.getString("label"), SunsetFormat.minutes(m.getInt("value")))
        }
        val nouns = fixture.getJSONArray("nouns")
        for (i in 0 until nouns.length()) {
            val n = nouns.getJSONObject(i)
            val watched = strings(n.getJSONArray("watched")).mapNotNull(SunEvent::from).toSet()
            assertEquals(n.getString("noun"), SunsetFormat.watchedNoun(watched, n.getBoolean("plural")))
        }
    }

    @Test fun demoWeekMatchesIos() {
        val demo = fixture.getJSONObject("demo")
        val forecast = DemoForecast.make(instant(demo.getDouble("now")), LA)
        assertForecast(demo.getJSONObject("forecast"), forecast)
    }

    private fun assertForecast(expected: JSONObject, actual: SunsetForecast) {
        assertEquals(expected.getString("timeZoneID"), actual.timeZoneId)
        val days = expected.getJSONArray("days")
        assertEquals(days.length(), actual.days.size)
        for (d in 0 until days.length()) {
            val day = days.getJSONObject(d)
            assertShow(day.getJSONObject("sunrise"), actual.days[d].sunrise)
            assertShow(day.getJSONObject("sunset"), actual.days[d].sunset)
        }
        val events = expected.getJSONArray("skyEvents")
        assertEquals(events.length(), actual.skyEvents.size)
        for (e in 0 until events.length()) {
            val event = events.getJSONObject(e)
            assertEquals(event.getString("kind"), actual.skyEvents[e].kind.raw)
            assertEquals(instant(event.getDouble("start")), actual.skyEvents[e].start)
            assertEquals(instant(event.getDouble("end")), actual.skyEvents[e].end)
        }
    }

    private fun assertShow(expected: JSONObject, show: SunShow) {
        assertEquals(expected.getString("event"), show.event.raw)
        assertEquals(instant(expected.getDouble("time")), show.time)
        val c = expected.getJSONArray("conditions")
        val actual = with(show.conditions) { listOf(cloudLow, cloudMid, cloudHigh, cloudLowTowardSun, humidity, visibility, precipitationChance) }
        actual.forEachIndexed { i, value -> assertEquals("condition $i", c.getDouble(i), value, 1e-6) }
        val s = expected.getJSONArray("score")
        assertEquals((0 until 6).map(s::getInt), with(show.score) { listOf(total, color, streaks, horizon, clarity, rainChance) })
        assertEquals(expected.getString("summary"), show.score.summary)
    }

    private fun strings(array: JSONArray) = (0 until array.length()).map(array::getString)
}
