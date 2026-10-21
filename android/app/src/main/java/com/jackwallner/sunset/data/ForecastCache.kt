package com.jackwallner.sunset.data

import com.jackwallner.sunset.model.SunEvent
import com.jackwallner.sunset.model.SunsetForecast

/**
 * The snapshot the widget and background refresh read and the app writes,
 * under the iOS App Group keys. Also holds the last location fix, because the
 * widget cannot ask for one itself.
 */
class ForecastCache(private val defaults: KeyValueStore) {
    data class Location(val latitude: Double, val longitude: Double, val placeName: String?)

    var forecast: SunsetForecast?
        get() = defaults.getString(FORECAST)?.let(ForecastCodec::decode)
        set(value) = if (value == null) defaults.remove(FORECAST) else defaults.putString(FORECAST, ForecastCodec.encode(value))

    var location: Location?
        get() {
            if (!defaults.contains(LATITUDE)) return null
            return Location(
                latitude = defaults.getString(LATITUDE)?.toDoubleOrNull() ?: return null,
                longitude = defaults.getString(LONGITUDE)?.toDoubleOrNull() ?: return null,
                placeName = defaults.getString(PLACE),
            )
        }
        set(value) {
            if (value == null) {
                listOf(LATITUDE, LONGITUDE, PLACE).forEach(defaults::remove)
                return
            }
            defaults.putString(LATITUDE, value.latitude.toString())
            defaults.putString(LONGITUDE, value.longitude.toString())
            if (value.placeName == null) defaults.remove(PLACE) else defaults.putString(PLACE, value.placeName)
        }

    var isPro: Boolean
        get() = defaults.getBoolean(PRO)
        set(value) = defaults.putBoolean(PRO, value)

    /** Which shows the user watches. Never empty: an empty or missing set means both. */
    var watchedEvents: Set<SunEvent>
        get() {
            if (!defaults.contains(WATCHED)) return SunEvent.entries.toSet()
            val events = defaults.getStringSet(WATCHED).mapNotNull(SunEvent::from).toSet()
            return events.ifEmpty { SunEvent.entries.toSet() }
        }
        set(value) = defaults.putStringSet(WATCHED, value.map { it.raw }.toSet())

    private companion object {
        /** Bumped when the snapshot changes shape, so an old one is dropped. */
        const val FORECAST = "sunset.forecast.v2"
        const val LATITUDE = "sunset.location.latitude"
        const val LONGITUDE = "sunset.location.longitude"
        const val PLACE = "sunset.location.place"
        const val PRO = "sunset.isPro"
        const val WATCHED = "sunset.watched"
    }
}
