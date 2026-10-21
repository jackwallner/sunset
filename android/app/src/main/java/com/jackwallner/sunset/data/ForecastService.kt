package com.jackwallner.sunset.data

import com.jackwallner.sunset.model.SkyConditions
import com.jackwallner.sunset.model.SkyEventDetector
import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.model.SunShow
import com.jackwallner.sunset.model.SunsetDay
import com.jackwallner.sunset.model.SunsetForecast
import com.jackwallner.sunset.model.SunsetScorer
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sign
import org.json.JSONArray
import org.json.JSONObject

/**
 * Fetches the sky from Open-Meteo, scores each sunrise and sunset, and picks
 * out storms, rainbow chances and fog. Ports `ForecastService.swift`: one
 * request carries the user's point and points about 80 km west and east. No
 * key, no account, and only rounded coordinates leave the device.
 */
object ForecastService {
    class Failure(message: String) : IOException(message)

    const val SUNWARD_OFFSET_KILOMETRES = 80.0
    private const val HOURLY =
        "cloud_cover_low,cloud_cover_mid,cloud_cover_high,relative_humidity_2m,visibility,precipitation_probability,precipitation,cloud_cover,weather_code"

    /** Blocking; call from an IO dispatcher. */
    fun fetch(latitude: Double, longitude: Double, days: Int = 8, now: Instant = Instant.now()): SunsetForecast {
        val connection = URL(url(latitude, longitude, days)).openConnection() as HttpURLConnection
        connection.connectTimeout = 15_000
        connection.readTimeout = 20_000
        try {
            if (connection.responseCode !in 200..299) throw Failure("HTTP ${connection.responseCode}")
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            return parse(body, latitude, longitude, now)
        } finally {
            connection.disconnect()
        }
    }

    fun url(latitude: Double, longitude: Double, days: Int): String {
        val (lat, lon) = rounded(latitude, longitude)
        val west = westPoint(lat, lon)
        val east = eastPoint(lat, lon)
        val query = listOf(
            "latitude" to "$lat,${west.first},${east.first}",
            "longitude" to "$lon,${west.second},${east.second}",
            "hourly" to HOURLY,
            "daily" to "sunrise,sunset",
            "timezone" to "auto",
            "forecast_days" to days.toString(),
        ).joinToString("&") { (name, value) -> "$name=${URLEncoder.encode(value, "UTF-8").replace("%2C", ",")}" }
        return "https://api.open-meteo.com/v1/forecast?$query"
    }

    /** Two decimals is about a kilometre, all a regional cloud forecast can resolve anyway. */
    fun rounded(latitude: Double, longitude: Double): Pair<Double, Double> =
        roundHundredths(latitude) to roundHundredths(longitude)

    fun westPoint(latitude: Double, longitude: Double) = offsetPoint(latitude, longitude, -1.0)

    fun eastPoint(latitude: Double, longitude: Double) = offsetPoint(latitude, longitude, 1.0)

    private fun offsetPoint(latitude: Double, longitude: Double, sign: Double): Pair<Double, Double> {
        val kmPerDegree = 111.32 * max(0.2, cos(latitude * Math.PI / 180))
        val offset = min(3.0, SUNWARD_OFFSET_KILOMETRES / kmPerDegree)
        var lon = longitude + sign * offset
        if (lon < -180) lon += 360
        if (lon > 180) lon -= 360
        return latitude to roundHundredths(lon)
    }

    /** Swift's `rounded()`: half away from zero. */
    private fun roundHundredths(value: Double): Double {
        val scaled = value * 100
        return sign(scaled) * floor(abs(scaled) + 0.5) / 100
    }

    fun parse(body: String, latitude: Double, longitude: Double, now: Instant = Instant.now()): SunsetForecast {
        val points = runCatching { JSONArray(body) }.getOrNull() ?: throw Failure("not an array")
        if (points.length() != 3) throw Failure("expected three points")
        val here = Point(points.getJSONObject(0))
        val west = Point(points.getJSONObject(1))
        val east = Point(points.getJSONObject(2))
        val zone = runCatching { ZoneId.of(here.timezone) }.getOrNull() ?: throw Failure("bad time zone")

        val hourDates = here.times.map { parseTime(it, zone) ?: throw Failure("bad hour") }
        if (hourDates.isEmpty()) throw Failure("no hours")

        fun show(event: SunEvent, time: Instant): SunShow? {
            val position = hourDates.indexOfLast { !it.isAfter(time) }
            if (position < 0) return null
            val toward = if (event == SunEvent.SUNSET) west else east
            val next = min(position + 1, hourDates.size - 1)
            val weight = if (next == position) 0.0 else (time.epochSecond - hourDates[position].epochSecond) / 3600.0
            val sky = SunsetScorer.interpolate(conditions(here, toward, position), conditions(here, toward, next), weight)
            return SunShow(event, time, sky, SunsetScorer.score(sky, event))
        }

        val days = here.sunsets.mapIndexedNotNull { index, sunsetString ->
            val sunsetTime = parseTime(sunsetString, zone) ?: return@mapIndexedNotNull null
            val sunriseTime = here.sunrises.getOrNull(index)?.let { parseTime(it, zone) } ?: return@mapIndexedNotNull null
            val sunset = show(SunEvent.SUNSET, sunsetTime) ?: return@mapIndexedNotNull null
            val sunrise = show(SunEvent.SUNRISE, sunriseTime) ?: return@mapIndexedNotNull null
            SunsetDay(sunrise, sunset)
        }
        if (days.isEmpty()) throw Failure("no sunset")

        val hours = hourDates.indices.map { index ->
            SkyEventDetector.Hour(
                time = hourDates[index],
                weatherCode = here.weatherCode?.getOrNull(index)?.toInt(),
                cloudCover = here.cloudCover?.getOrNull(index),
                precipitation = here.precipitation?.getOrNull(index),
                precipitationChance = here.precipitationChance.getOrNull(index),
                visibility = here.visibility.getOrNull(index),
            )
        }
        return SunsetForecast(
            latitude = latitude,
            longitude = longitude,
            placeName = null,
            timeZoneId = here.timezone,
            fetched = now,
            days = days,
            skyEvents = SkyEventDetector.detect(hours, latitude, longitude),
        )
    }

    /** Like iOS's strict DateFormatter: a local time that falls in a DST gap is invalid, not shifted. */
    private fun parseTime(value: String, zone: ZoneId): Instant? = runCatching {
        val local = LocalDateTime.parse(value)
        val zoned = local.atZone(zone)
        if (zoned.toLocalDateTime() != local) null else zoned.toInstant()
    }.getOrNull()

    private fun conditions(here: Point, toward: Point, index: Int): SkyConditions {
        fun value(array: List<Double?>, fallback: Double) = array.getOrNull(index) ?: fallback
        return SkyConditions(
            cloudLow = value(here.cloudLow, 0.0),
            cloudMid = value(here.cloudMid, 0.0),
            cloudHigh = value(here.cloudHigh, 0.0),
            cloudLowTowardSun = value(toward.cloudLow, value(here.cloudLow, 0.0)),
            humidity = value(here.humidity, 60.0),
            visibility = value(here.visibility, 20_000.0),
            precipitationChance = value(here.precipitationChance, 0.0),
        )
    }

    /** One Open-Meteo location. The three newer hourly series are optional, as on iOS. */
    private class Point(json: JSONObject) {
        val timezone: String = json.getString("timezone")
        private val hourly = json.getJSONObject("hourly")
        private val daily = json.getJSONObject("daily")
        val times: List<String> = strings(hourly.getJSONArray("time"))
        val cloudLow = numbers(hourly, "cloud_cover_low") ?: throw Failure("missing low cloud")
        val cloudMid = numbers(hourly, "cloud_cover_mid") ?: throw Failure("missing mid cloud")
        val cloudHigh = numbers(hourly, "cloud_cover_high") ?: throw Failure("missing high cloud")
        val humidity = numbers(hourly, "relative_humidity_2m") ?: throw Failure("missing humidity")
        val visibility = numbers(hourly, "visibility") ?: throw Failure("missing visibility")
        val precipitationChance = numbers(hourly, "precipitation_probability") ?: throw Failure("missing rain chance")
        val precipitation = numbers(hourly, "precipitation")
        val cloudCover = numbers(hourly, "cloud_cover")
        val weatherCode = numbers(hourly, "weather_code")
        val sunrises: List<String> = strings(daily.getJSONArray("sunrise"))
        val sunsets: List<String> = strings(daily.getJSONArray("sunset"))

        private fun strings(array: JSONArray) = (0 until array.length()).map { array.getString(it) }

        private fun numbers(json: JSONObject, key: String): List<Double?>? {
            val array = json.optJSONArray(key) ?: return null
            return (0 until array.length()).map { if (array.isNull(it)) null else array.getDouble(it) }
        }
    }
}
