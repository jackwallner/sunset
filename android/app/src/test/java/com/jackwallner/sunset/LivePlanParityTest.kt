package com.jackwallner.sunset

import com.jackwallner.sunset.data.ForecastService
import com.jackwallner.sunset.model.AlertPlanner
import com.jackwallner.sunset.model.SkyEvent
import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.model.SunsetFormat
import java.time.Instant
import java.util.Locale
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.BeforeClass
import org.junit.Test

/**
 * The alerts the real iOS `NotificationService.plan` builds for 51 live
 * forecasts (fetched 2026-10-31, several `now` values, thresholds and leads,
 * every sky event kind on) must be the alerts `AlertPlanner` builds here:
 * same ids, fire instants, titles and bodies.
 */
class LivePlanParityTest {
    companion object {
        @BeforeClass @JvmStatic fun locale() {
            Locale.setDefault(Locale.US)
            SunsetFormat.use24Hour = false
        }

        /** macOS puts a narrow no-break space before AM/PM. */
        private fun normal(text: String) = text.replace('\u202f', ' ').replace('\u00a0', ' ')
    }

    private fun resource(path: String) = LivePlanParityTest::class.java.getResource(path)!!.readText()

    @Test fun everyLivePlanMatchesIos() {
        val expected = JSONObject(resource("/live-plan-expected.json"))
        val fetched = Instant.ofEpochSecond(1_793_440_000)
        var alerts = 0
        for (city in expected.keys().asSequence().toList().sorted()) {
            val entry = expected.getJSONObject(city)
            val forecast = ForecastService.parse(resource("/live/$city.json"), entry.getDouble("lat"), entry.getDouble("lon"), fetched)
            val plans = entry.getJSONObject("plans")
            for (key in plans.keys().asSequence().toList().sorted()) {
                val (now, threshold, lead) = key.split("|").map { it.toLong() }
                val want = plans.getJSONArray(key).let { array ->
                    (0 until array.length()).map { array.getJSONArray(it) }.map {
                        listOf(it.getString(0), it.getLong(1), it.getString(2), normal(it.getString(3)))
                    }
                }
                val got = AlertPlanner.plan(
                    forecast, SunEvent.entries.toSet(), threshold.toInt(), lead.toInt(), SkyEvent.Kind.entries.toSet(), Instant.ofEpochSecond(now),
                ).map { listOf(it.identifier, it.fireDate.epochSecond, it.title, normal(it.body)) }
                assertEquals("$city plan $key", want.sortedBy { "${it[1]}${it[0]}" }, got.sortedBy { "${it[1]}${it[0]}" })
                alerts += got.size
            }
        }
        assertEquals(3187, alerts)
    }
}
