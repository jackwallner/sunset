package com.jackwallner.sunset.model

import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * A fixed, good-looking week for screenshots, UI tests and offline review
 * runs (`demoForecast`), ported from `DemoForecast.swift`. Real scorer,
 * made-up skies.
 */
object DemoForecast {
    // (low here, mid, high, low toward the sun, humidity, visibility km, rain %)
    private val SUNSETS = listOf(
        doubleArrayOf(5.0, 28.0, 52.0, 6.0, 42.0, 32.0, 5.0), doubleArrayOf(10.0, 35.0, 30.0, 25.0, 55.0, 26.0, 10.0),
        doubleArrayOf(70.0, 55.0, 20.0, 85.0, 85.0, 10.0, 60.0), doubleArrayOf(3.0, 22.0, 48.0, 4.0, 40.0, 35.0, 0.0),
        doubleArrayOf(20.0, 40.0, 60.0, 35.0, 60.0, 20.0, 20.0), doubleArrayOf(85.0, 60.0, 10.0, 90.0, 90.0, 8.0, 75.0),
        doubleArrayOf(8.0, 30.0, 45.0, 15.0, 50.0, 28.0, 5.0), doubleArrayOf(15.0, 25.0, 40.0, 20.0, 52.0, 24.0, 10.0),
    )
    private val SUNRISES = listOf(
        doubleArrayOf(20.0, 30.0, 40.0, 30.0, 80.0, 18.0, 10.0), doubleArrayOf(8.0, 25.0, 45.0, 10.0, 70.0, 24.0, 5.0),
        doubleArrayOf(40.0, 50.0, 30.0, 50.0, 88.0, 12.0, 30.0), doubleArrayOf(60.0, 40.0, 10.0, 70.0, 92.0, 9.0, 40.0),
        doubleArrayOf(10.0, 30.0, 55.0, 12.0, 68.0, 22.0, 5.0), doubleArrayOf(5.0, 20.0, 50.0, 5.0, 65.0, 28.0, 0.0),
        doubleArrayOf(50.0, 45.0, 20.0, 60.0, 90.0, 10.0, 35.0), doubleArrayOf(15.0, 35.0, 35.0, 25.0, 75.0, 20.0, 10.0),
    )

    fun make(now: Instant = Instant.now(), zone: ZoneId = ZoneId.systemDefault()): SunsetForecast {
        val today = now.atZone(zone).toLocalDate()
        fun sky(v: DoubleArray) = SkyConditions(v[0], v[1], v[2], v[3], v[4], v[5] * 1000, v[6])
        fun at(day: Int, hour: Int, minute: Int): Instant =
            ZonedDateTime.of(today.plusDays(day.toLong()), java.time.LocalTime.of(hour, minute), zone).toInstant()

        val days = (0 until 8).map { index ->
            val rise = sky(SUNRISES[index])
            val set = sky(SUNSETS[index])
            SunsetDay(
                sunrise = SunShow(SunEvent.SUNRISE, at(index, 7, 14 + index), rise, SunsetScorer.score(rise, SunEvent.SUNRISE)),
                sunset = SunShow(SunEvent.SUNSET, at(index, 18, 31 - 2 * index), set, SunsetScorer.score(set, SunEvent.SUNSET)),
            )
        }
        val events = listOf(
            SkyEvent(SkyEvent.Kind.RAINBOW, at(1, 17, 0), at(1, 18, 0)),
            SkyEvent(SkyEvent.Kind.FOG, at(2, 6, 0), at(2, 9, 0)),
            SkyEvent(SkyEvent.Kind.THUNDERSTORM, at(2, 15, 0), at(2, 18, 0)),
            SkyEvent(SkyEvent.Kind.THUNDERSTORM, at(5, 14, 0), at(5, 16, 0)),
        )
        return SunsetForecast(45.63, -122.52, "Vancouver, WA", zone.id, now, days, events)
    }

    /** The onboarding and widget-preview example: an epic-looking sunset at 6:31 pm today. */
    fun preview(now: Instant = Instant.now(), zone: ZoneId = ZoneId.systemDefault()): SunShow {
        val time = now.atZone(zone).withHour(18).withMinute(31).withSecond(0).withNano(0).toInstant()
        val sky = SkyConditions(5.0, 25.0, 50.0, 8.0, 45.0, 30_000.0, 5.0)
        return SunShow(SunEvent.SUNSET, time, SkyConditions.CLEAR, SunsetScorer.score(sky))
    }
}
