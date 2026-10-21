package com.jackwallner.sunset.model

import java.time.Duration
import java.time.Instant
import java.time.ZoneId

/**
 * The two shows a day puts on. Sunrise light comes from the east, sunset
 * light from the west, so each is scored against its own horizon.
 */
enum class SunEvent(val raw: String, val title: String, val direction: String) {
    SUNRISE("sunrise", "Sunrise", "east"),
    SUNSET("sunset", "Sunset", "west");

    companion object {
        fun from(raw: String?): SunEvent? = entries.firstOrNull { it.raw == raw }
    }
}

/**
 * The sky at sunrise or sunset, as the forecast models see it. Every value
 * is 0 to 100 except [visibility], which is metres. [cloudLowTowardSun] is
 * low cloud about 80 km toward the sun, where the light comes from.
 */
data class SkyConditions(
    val cloudLow: Double,
    val cloudMid: Double,
    val cloudHigh: Double,
    val cloudLowTowardSun: Double,
    val humidity: Double,
    val visibility: Double,
    val precipitationChance: Double,
) {
    companion object {
        val CLEAR = SkyConditions(0.0, 0.0, 0.0, 0.0, 40.0, 30_000.0, 0.0)
    }
}

/** How the sky is expected to look, 0 to 100, with the factors behind it. */
data class SunsetScore(
    val total: Int,
    val color: Int,
    val streaks: Int,
    val horizon: Int,
    val clarity: Int,
    val rainChance: Int,
    val summary: String,
) {
    enum class Grade(val title: String) {
        DULL("Dull"), FAIR("Fair"), GOOD("Good"), GREAT("Great"), EPIC("Epic");

        companion object {
            fun of(total: Int): Grade = when {
                total < 30 -> DULL
                total < 50 -> FAIR
                total < 70 -> GOOD
                total < 85 -> GREAT
                else -> EPIC
            }
        }
    }

    data class Factor(val id: String, val name: String, val value: Int, val detail: String)

    val grade: Grade get() = Grade.of(total)

    val factors: List<Factor>
        get() = listOf(
            Factor("color", "Color", color, "High and mid clouds that catch the light"),
            Factor("streaks", "Streaks", streaks, "Thin cirrus with room to glow"),
            Factor("horizon", "Horizon", horizon, "Open sky toward the sun"),
            Factor("clarity", "Clarity", clarity, "Dry, clean air for vivid tones"),
        )
}

/** One sunrise or one sunset: when it happens and what the sky should do. */
data class SunShow(
    val event: SunEvent,
    val time: Instant,
    val conditions: SkyConditions,
    val score: SunsetScore,
) {
    /** Color peaks just before sunrise and just after sunset, so the window leans to the dark side. */
    val bestWindowStart: Instant
        get() = time.minus(Duration.ofMinutes(if (event == SunEvent.SUNSET) 10 else 25))

    val bestWindowEnd: Instant
        get() = time.plus(Duration.ofMinutes(if (event == SunEvent.SUNSET) 25 else 10))

    /** A show stays current until half an hour after the moment, then the next one takes over. */
    fun isOver(now: Instant): Boolean = !time.plus(Duration.ofMinutes(30)).isAfter(now)
}

/** Weather worth looking up for, beyond the sunrise and sunset. */
data class SkyEvent(val kind: Kind, val start: Instant, val end: Instant) {
    enum class Kind(val raw: String, val title: String, val detail: String) {
        THUNDERSTORM("thunderstorm", "Thunderstorms", "Lightning in the forecast near you"),
        RAINBOW("rainbow", "Rainbow chance", "Showers with a low sun breaking through"),
        FOG("fog", "Fog", "Low visibility that softens the light");

        companion object {
            fun from(raw: String?): Kind? = entries.firstOrNull { it.raw == raw }
        }
    }

    val id: String get() = "${kind.raw}-${start.epochSecond}"
}

/** One calendar day: its sunrise, its sunset. */
data class SunsetDay(val sunrise: SunShow, val sunset: SunShow) {
    fun show(event: SunEvent): SunShow = if (event == SunEvent.SUNRISE) sunrise else sunset
}

data class SunsetForecast(
    val latitude: Double,
    val longitude: Double,
    val placeName: String?,
    val timeZoneId: String,
    val fetched: Instant,
    val days: List<SunsetDay>,
    val skyEvents: List<SkyEvent>,
) {
    val zone: ZoneId get() = runCatching { ZoneId.of(timeZoneId) }.getOrDefault(ZoneId.systemDefault())

    /** Every watched sunrise and sunset that is not over yet, in order. */
    fun upcomingShows(events: Set<SunEvent> = SunEvent.entries.toSet(), now: Instant = Instant.now()): List<SunShow> =
        days.flatMap { listOf(it.sunrise, it.sunset) }
            .filter { it.event in events && !it.isOver(now) }
            .sortedBy { it.time }

    /** The days from today on, dropping a day once both its shows are over. */
    fun upcomingDays(now: Instant = Instant.now()): List<SunsetDay> = days.filter { !it.sunset.isOver(now) }

    fun upcomingSkyEvents(now: Instant = Instant.now(), within: Duration? = null): List<SkyEvent> =
        skyEvents.filter { event ->
            event.end.isAfter(now) && (within == null || event.start.isBefore(now.plus(within)))
        }

    fun skyEvents(day: SunsetDay): List<SkyEvent> {
        val date = day.sunset.time.atZone(zone).toLocalDate()
        return skyEvents.filter { it.start.atZone(zone).toLocalDate() == date }
    }

    fun isStale(now: Instant = Instant.now(), maxAge: Duration = Duration.ofHours(3)): Boolean =
        Duration.between(fetched, now) > maxAge

    fun isSameLocation(latitude: Double, longitude: Double): Boolean =
        kotlin.math.abs(this.latitude - latitude) < 0.05 && kotlin.math.abs(this.longitude - longitude) < 0.05
}
