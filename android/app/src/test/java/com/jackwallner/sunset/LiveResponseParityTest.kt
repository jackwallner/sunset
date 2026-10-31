package com.jackwallner.sunset

import com.jackwallner.sunset.data.ForecastService
import java.time.Instant
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Live Open-Meteo responses (51 places, requested 2026-10-31 at the app's own
 * URL), parsed by the real iOS sources into `live-expected.json`, must parse to
 * the same instants, conditions, scores, summaries and sky events here. The
 * synthetic fixtures in `PortParityTest` cannot see a difference that only a
 * real response shows: a sunward point on its own clock, half-hour zones, the
 * antimeridian, a daylight saving change inside the window.
 */
class LiveResponseParityTest {
    private val now = Instant.ofEpochSecond(1_793_440_000)

    private fun resource(path: String) = LiveResponseParityTest::class.java.getResource(path)!!.readText()

    @Test fun everyLiveResponseParsesLikeIos() {
        val expected = JSONObject(resource("/live-expected.json"))
        val cities = expected.keys().asSequence().toList().sorted()
        assertEquals(51, cities.size)
        var shows = 0
        for (city in cities) {
            val want = expected.getJSONObject(city)
            val got = ForecastService.parse(resource("/live/$city.json"), want.getDouble("lat"), want.getDouble("lon"), now)
            assertEquals("$city zone", want.getString("tz"), got.timeZoneId)

            val wantShows = want.getJSONArray("shows")
            val gotShows = got.days.flatMap { listOf(it.sunrise, it.sunset) }
            assertEquals("$city show count", wantShows.length(), gotShows.size)
            for (i in gotShows.indices) {
                val w = wantShows.getJSONObject(i)
                val g = gotShows[i]
                val label = "$city show $i ${g.event.raw}"
                assertEquals("$label event", w.getString("event"), g.event.raw)
                assertEquals("$label time", w.getLong("t"), g.time.epochSecond)
                val c = g.conditions
                val conditions = listOf(
                    "low" to c.cloudLow, "mid" to c.cloudMid, "high" to c.cloudHigh, "toward" to c.cloudLowTowardSun,
                    "hum" to c.humidity, "vis" to c.visibility, "pop" to c.precipitationChance,
                )
                for ((key, value) in conditions) assertEquals("$label $key", w.getDouble(key), value, 1e-9)
                val s = g.score
                val scores = listOf(
                    "score" to s.total, "color" to s.color, "streaks" to s.streaks,
                    "horizon" to s.horizon, "clarity" to s.clarity, "rain" to s.rainChance,
                )
                for ((key, value) in scores) assertEquals("$label $key", w.getInt(key), value)
                assertEquals("$label summary", w.getString("summary"), s.summary)
                shows++
            }

            val wantEvents = want.getJSONArray("events").let { array ->
                (0 until array.length()).map { array.getJSONObject(it) }.map { Triple(it.getLong("start"), it.getString("kind"), it.getLong("end")) }
            }.sortedWith(compareBy({ it.first }, { it.second }))
            val gotEvents = got.skyEvents.map { Triple(it.start.epochSecond, it.kind.raw, it.end.epochSecond) }
                .sortedWith(compareBy({ it.first }, { it.second }))
            assertEquals("$city sky events", wantEvents, gotEvents)
        }
        assertEquals(816, shows)
    }
}
