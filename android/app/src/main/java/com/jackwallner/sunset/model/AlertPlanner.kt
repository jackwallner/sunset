package com.jackwallner.sunset.model

import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * What alerts should exist for a forecast, in fire order: the pure half of
 * `NotificationService.swift`, pinned by the same tests. Sunrise alerts and
 * overnight sky events land at 8 pm the evening before; nothing fires
 * 10 pm to 7 am.
 */
object AlertPlanner {
    const val PREFIX = "sunset.alert."
    const val QUIET_START_HOUR = 22
    const val QUIET_END_HOUR = 7
    const val EVENING_BEFORE_HOUR = 20

    data class Planned(val identifier: String, val fireDate: Instant, val title: String, val body: String)

    fun plan(
        forecast: SunsetForecast,
        watched: Set<SunEvent>,
        threshold: Int,
        leadMinutes: Int,
        skyEventKinds: Set<SkyEvent.Kind>,
        now: Instant,
    ): List<Planned> {
        val zone = forecast.zone
        val planned = mutableListOf<Planned>()

        for (show in forecast.days.flatMap { listOf(it.sunrise, it.sunset) }) {
            if (show.event !in watched || show.score.total < threshold) continue
            // Nobody wants a buzz at 5:40 am, so sunrise alerts land the evening before.
            val fire = if (show.event == SunEvent.SUNSET) {
                show.time.minus(Duration.ofMinutes(leadMinutes.toLong()))
            } else {
                eveningBefore(show.time, zone)
            }
            if (!fire.isAfter(now) || !fire.isBefore(show.time)) continue
            val time = SunsetFormat.time(show.time, zone)
            val start = SunsetFormat.time(show.bestWindowStart, zone)
            val title = if (show.event == SunEvent.SUNSET) {
                "${show.score.grade.title} sunset tonight: ${show.score.total}"
            } else {
                "${show.score.grade.title} sunrise tomorrow: ${show.score.total}"
            }
            val body = "${show.score.summary} ${show.event.title} at $time, best light from $start."
            planned += Planned(PREFIX + show.event.raw + "." + dayKey(show.time, zone), fire, title, body)
        }

        for (event in forecast.skyEvents) {
            if (event.kind !in skyEventKinds) continue
            val fire = skyEventFireDate(event, zone) ?: continue
            if (!fire.isAfter(now)) continue
            val time = SunsetFormat.time(event.start, zone)
            val day = SunsetFormat.relativeDay(event.start, zone, now = fire)
            planned += Planned(PREFIX + event.id, fire, skyEventTitle(event.kind, day), skyEventBody(event, time, zone))
        }
        return planned.sortedBy { it.fireDate }
    }

    /** An hour of warning, pulled out of quiet hours to the evening before. */
    fun skyEventFireDate(event: SkyEvent, zone: ZoneId): Instant? {
        val fire = event.start.minus(Duration.ofHours(1))
        if (!isQuiet(fire, zone)) return fire
        val evening = eveningBefore(event.start, zone)
        return if (evening.isBefore(event.start)) evening else null
    }

    fun isQuiet(instant: Instant, zone: ZoneId): Boolean {
        val hour = instant.atZone(zone).hour
        return hour >= QUIET_START_HOUR || hour < QUIET_END_HOUR
    }

    /** 8 pm on the evening before [instant], or the same evening when it is itself late at night. */
    fun eveningBefore(instant: Instant, zone: ZoneId): Instant {
        val local = instant.atZone(zone)
        val base = if (local.hour >= EVENING_BEFORE_HOUR) local else local.minusDays(1)
        return base.withHour(EVENING_BEFORE_HOUR).withMinute(0).withSecond(0).withNano(0).toInstant()
    }

    fun dayKey(instant: Instant, zone: ZoneId): String = DateTimeFormatter.ISO_LOCAL_DATE.format(instant.atZone(zone))

    private fun skyEventTitle(kind: SkyEvent.Kind, day: String): String = when (kind) {
        SkyEvent.Kind.THUNDERSTORM -> "Thunderstorms $day"
        SkyEvent.Kind.RAINBOW -> "Rainbow chance $day"
        SkyEvent.Kind.FOG -> "Fog $day"
    }

    private fun skyEventBody(event: SkyEvent, time: String, zone: ZoneId): String {
        val until = SunsetFormat.time(event.end, zone)
        return when (event.kind) {
            SkyEvent.Kind.THUNDERSTORM ->
                "Storms are forecast from about $time to $until. Watch the sky from somewhere safe indoors."
            SkyEvent.Kind.RAINBOW ->
                "Showers with a low sun around $time. Face away from the sun to look for a bow."
            SkyEvent.Kind.FOG ->
                "Fog is forecast from about $time to $until. Soft light for photos, slow going on the roads."
        }
    }
}
