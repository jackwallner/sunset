package com.jackwallner.sunset.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.sunset.model.SunShow
import com.jackwallner.sunset.model.SunsetForecast
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * The forecast the app shows. Starts from the cache so the screen is never
 * blank, refreshes from Open-Meteo when it is stale or the location moved, and
 * rewrites alerts and the widget after every successful fetch.
 */
class ForecastStore(
    private val cache: ForecastCache,
    private val scope: CoroutineScope,
    private val fetcher: (Double, Double) -> SunsetForecast = { lat, lon -> ForecastService.fetch(lat, lon) },
) {
    /** Called with the fresh forecast after every successful fetch. */
    var onFetched: (SunsetForecast) -> Unit = {}

    var forecast by mutableStateOf(cache.forecast)
        private set
    var isLoading by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set

    /** Debug and screenshot runs pin a fixed week; nothing refreshes over it. */
    var isPinned = false
        private set
    private var inFlight: Job? = null

    fun pin(fixed: SunsetForecast) {
        isPinned = true
        forecast = fixed
    }

    fun nextShow(watched: Set<com.jackwallner.sunset.model.SunEvent>, now: Instant = Instant.now()): SunShow? =
        forecast?.upcomingShows(watched, now)?.firstOrNull()

    /** Refreshes when the cache is older than three hours or the location moved. [force] skips both checks. */
    fun refresh(location: ForecastCache.Location, force: Boolean = false) {
        if (isPinned) return
        val current = forecast
        if (!force && current != null && !current.isStale() && current.isSameLocation(location.latitude, location.longitude)) {
            applyPlace(location.placeName)
            return
        }
        if (inFlight?.isActive == true && !force) return
        inFlight = scope.launch { load(location) }
    }

    suspend fun load(location: ForecastCache.Location) {
        if (isPinned) return
        isLoading = true
        try {
            val fresh = withContext(Dispatchers.IO) { fetcher(location.latitude, location.longitude) }
                .copy(placeName = location.placeName)
            forecast = fresh
            errorMessage = null
            cache.forecast = fresh
            onFetched(fresh)
        } catch (error: kotlinx.coroutines.CancellationException) {
            throw error
        } catch (_: Throwable) {
            errorMessage = if (forecast == null) {
                "Couldn't load the forecast. Check your connection and try again."
            } else {
                "Showing the last forecast. Couldn't reach the weather service."
            }
        } finally {
            isLoading = false
        }
    }

    private fun applyPlace(placeName: String?) {
        val current = forecast ?: return
        if (placeName == null || current.placeName == placeName) return
        forecast = current.copy(placeName = placeName)
        cache.forecast = forecast
    }
}
