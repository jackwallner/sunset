package com.jackwallner.sunset.data

import com.jackwallner.sunset.model.SkyConditions
import com.jackwallner.sunset.model.SkyEvent
import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.model.SunShow
import com.jackwallner.sunset.model.SunsetDay
import com.jackwallner.sunset.model.SunsetForecast
import com.jackwallner.sunset.model.SunsetScore
import java.time.Instant
import org.json.JSONArray
import org.json.JSONObject

/** The cached snapshot's JSON shape. A decode failure drops the snapshot instead of crashing. */
object ForecastCodec {
    fun encode(forecast: SunsetForecast): String = JSONObject().apply {
        put("latitude", forecast.latitude)
        put("longitude", forecast.longitude)
        forecast.placeName?.let { put("placeName", it) }
        put("timeZoneID", forecast.timeZoneId)
        put("fetched", forecast.fetched.toEpochMilli())
        put("days", JSONArray(forecast.days.map { day ->
            JSONObject().put("sunrise", show(day.sunrise)).put("sunset", show(day.sunset))
        }))
        put("skyEvents", JSONArray(forecast.skyEvents.map { event ->
            JSONObject().put("kind", event.kind.raw).put("start", event.start.toEpochMilli()).put("end", event.end.toEpochMilli())
        }))
    }.toString()

    fun decode(text: String): SunsetForecast? = runCatching {
        val json = JSONObject(text)
        val days = json.getJSONArray("days")
        val events = json.getJSONArray("skyEvents")
        SunsetForecast(
            latitude = json.getDouble("latitude"),
            longitude = json.getDouble("longitude"),
            placeName = if (json.has("placeName")) json.getString("placeName") else null,
            timeZoneId = json.getString("timeZoneID"),
            fetched = Instant.ofEpochMilli(json.getLong("fetched")),
            days = (0 until days.length()).map {
                val day = days.getJSONObject(it)
                SunsetDay(show(day.getJSONObject("sunrise")), show(day.getJSONObject("sunset")))
            },
            skyEvents = (0 until events.length()).mapNotNull {
                val event = events.getJSONObject(it)
                val kind = SkyEvent.Kind.from(event.getString("kind")) ?: return@mapNotNull null
                SkyEvent(kind, Instant.ofEpochMilli(event.getLong("start")), Instant.ofEpochMilli(event.getLong("end")))
            },
        )
    }.getOrNull()

    private fun show(show: SunShow): JSONObject = JSONObject().apply {
        put("event", show.event.raw)
        put("time", show.time.toEpochMilli())
        val c = show.conditions
        put("conditions", JSONObject()
            .put("cloudLow", c.cloudLow).put("cloudMid", c.cloudMid).put("cloudHigh", c.cloudHigh)
            .put("cloudLowTowardSun", c.cloudLowTowardSun).put("humidity", c.humidity)
            .put("visibility", c.visibility).put("precipitationChance", c.precipitationChance))
        val s = show.score
        put("score", JSONObject()
            .put("total", s.total).put("color", s.color).put("streaks", s.streaks).put("horizon", s.horizon)
            .put("clarity", s.clarity).put("rainChance", s.rainChance).put("summary", s.summary))
    }

    private fun show(json: JSONObject): SunShow {
        val c = json.getJSONObject("conditions")
        val s = json.getJSONObject("score")
        return SunShow(
            event = SunEvent.from(json.getString("event")) ?: error("bad event"),
            time = Instant.ofEpochMilli(json.getLong("time")),
            conditions = SkyConditions(
                c.getDouble("cloudLow"), c.getDouble("cloudMid"), c.getDouble("cloudHigh"),
                c.getDouble("cloudLowTowardSun"), c.getDouble("humidity"), c.getDouble("visibility"),
                c.getDouble("precipitationChance"),
            ),
            score = SunsetScore(
                s.getInt("total"), s.getInt("color"), s.getInt("streaks"), s.getInt("horizon"),
                s.getInt("clarity"), s.getInt("rainChance"), s.getString("summary"),
            ),
        )
    }
}
