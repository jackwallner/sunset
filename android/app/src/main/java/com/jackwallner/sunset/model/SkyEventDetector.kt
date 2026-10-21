package com.jackwallner.sunset.model

import java.time.Duration
import java.time.Instant
import kotlin.math.PI
import kotlin.math.asin
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * Finds thunderstorms, rainbow chances and fog in the hourly forecast. Each
 * hour is classified on its own, then runs of the same kind merge into one
 * event, so a three-hour storm is one alert, not three.
 */
object SkyEventDetector {
    data class Hour(
        val time: Instant,
        /** WMO weather interpretation code, as Open-Meteo reports it. */
        val weatherCode: Int? = null,
        val cloudCover: Double? = null,
        val precipitation: Double? = null,
        val precipitationChance: Double? = null,
        val visibility: Double? = null,
    )

    fun detect(hours: List<Hour>, latitude: Double, longitude: Double): List<SkyEvent> {
        val events = mutableListOf<SkyEvent>()
        for (hour in hours) {
            val elevation = SolarPosition.elevation(hour.time, latitude, longitude)
            for (kind in kinds(hour, elevation)) {
                val end = hour.time.plus(Duration.ofHours(1))
                val index = events.indexOfLast { it.kind == kind }
                if (index >= 0 && !events[index].end.isBefore(hour.time)) {
                    events[index] = events[index].copy(end = end)
                } else {
                    events += SkyEvent(kind, hour.time, end)
                }
            }
        }
        return events.sortedBy { it.start }
    }

    fun kinds(hour: Hour, sunElevation: Double): List<SkyEvent.Kind> {
        val kinds = mutableListOf<SkyEvent.Kind>()
        val code = hour.weatherCode ?: -1
        if (code in 95..99) kinds += SkyEvent.Kind.THUNDERSTORM
        if (isRainbowHour(hour, code, sunElevation)) kinds += SkyEvent.Kind.RAINBOW
        if (code == 45 || code == 48 || (hour.visibility ?: Double.POSITIVE_INFINITY) < 1_000) kinds += SkyEvent.Kind.FOG
        return kinds
    }

    /** Falling rain and direct sun at once, with the sun low enough for the bow to clear the horizon. */
    private fun isRainbowHour(hour: Hour, code: Int, sunElevation: Double): Boolean {
        if (sunElevation !in 2.0..42.0) return false
        val cover = hour.cloudCover ?: return false
        if (cover < 20 || cover > 75) return false
        val showery = code in 80..82 || code in 51..63
        val wet = (hour.precipitation ?: 0.0) >= 0.1 && (hour.precipitationChance ?: 0.0) >= 35
        return showery && wet
    }
}

/** Sun elevation from the NOAA approximation, good to a fraction of a degree. */
object SolarPosition {
    fun elevation(time: Instant, latitude: Double, longitude: Double): Double {
        val seconds = time.epochSecond + time.nano / 1e9
        val days = seconds / 86_400 + 2_440_587.5 - 2_451_545.0
        val meanLongitude = normalize(280.460 + 0.985_647_4 * days)
        val meanAnomaly = radians(normalize(357.528 + 0.985_600_3 * days))
        val eclipticLongitude = radians(meanLongitude + 1.915 * sin(meanAnomaly) + 0.020 * sin(2 * meanAnomaly))
        val obliquity = radians(23.439 - 0.000_000_4 * days)
        val declination = asin(sin(obliquity) * sin(eclipticLongitude))
        val rightAscension = atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude))

        val siderealHours = 18.697_374_558 + 24.065_709_824_419_08 * days
        val localSidereal = radians(normalize(siderealHours * 15 + longitude))
        val hourAngle = localSidereal - rightAscension
        val lat = radians(latitude)
        val sine = sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle)
        return asin(min(1.0, max(-1.0, sine))) * 180 / PI
    }

    private fun radians(degrees: Double) = degrees * PI / 180

    private fun normalize(degrees: Double): Double {
        val value = degrees % 360
        return if (value < 0) value + 360 else value
    }
}
