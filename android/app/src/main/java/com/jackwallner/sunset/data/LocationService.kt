package com.jackwallner.sunset.data

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Geocoder
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.CancellationSignal
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import kotlin.coroutines.resume
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

/**
 * One coarse fix, reverse geocoded to a town name, cached for the widget and
 * background refresh. Approximate location only, no tracking and no
 * background updates: the forecast needs a region, not a street.
 */
class LocationService(
    private val context: Context,
    private val cache: ForecastCache,
    private val defaults: KeyValueStore,
    private val scope: CoroutineScope,
) {
    sealed interface Status {
        data object Unknown : Status
        data object Waiting : Status
        data object Denied : Status
        data class Located(val fix: ForecastCache.Location) : Status
    }

    /** Set by the activity: shows the system permission dialog and returns whether it was granted. */
    var requestPermission: (suspend () -> Boolean)? = null

    var status by mutableStateOf<Status>(cache.location?.let(Status::Located) ?: Status.Unknown)
        private set

    private var onFix: ((ForecastCache.Location) -> Unit)? = null

    val location: ForecastCache.Location?
        get() = (status as? Status.Located)?.fix ?: cache.location

    val isAuthorized: Boolean
        get() = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    /** Asked once and refused: Android will not show the dialog again, so Settings is the way back. */
    val isDenied: Boolean get() = !isAuthorized && defaults.getBoolean(ASKED) && status is Status.Denied

    /** Calls [onFix] when a new fix lands. Calling with no closure just refreshes. */
    fun request(onFix: ((ForecastCache.Location) -> Unit)? = null) {
        if (onFix != null) this.onFix = onFix
        if (isAuthorized) {
            refresh()
            return
        }
        val ask = requestPermission ?: return
        status = Status.Waiting
        scope.launch {
            defaults.putBoolean(ASKED, true)
            if (ask()) refresh() else status = Status.Denied
        }
    }

    fun refresh() {
        if (!isAuthorized) return
        if (status is Status.Unknown || status is Status.Denied) status = Status.Waiting
        scope.launch {
            val fix = currentLocation()
            if (fix == null) {
                if (cache.location == null) status = Status.Unknown else status = Status.Located(cache.location!!)
                return@launch
            }
            store(fix.latitude, fix.longitude)
        }
    }

    /** Debug runs and reviewers on an emulator: a fixed location keeps the forecast real. */
    fun useDemoLocation() {
        val demo = ForecastCache.Location(45.63, -122.52, "Vancouver, WA")
        cache.location = demo
        status = Status.Located(demo)
        onFix?.invoke(demo)
    }

    private suspend fun store(latitude: Double, longitude: Double) {
        // Only the rounded point (about a kilometre) goes to the system geocoder, as to Open-Meteo.
        val (lat, lon) = ForecastService.rounded(latitude, longitude)
        val place = withContext(Dispatchers.IO) { placeName(lat, lon) } ?: cache.location?.placeName
        val fix = ForecastCache.Location(latitude, longitude, place)
        cache.location = fix
        status = Status.Located(fix)
        onFix?.invoke(fix)
    }

    @SuppressLint("MissingPermission")
    private suspend fun currentLocation(): Location? {
        val manager = context.getSystemService(LocationManager::class.java) ?: return null
        val providers = manager.getProviders(true)
        val provider = listOf(fusedProvider(), LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
            .firstOrNull { it != null && it in providers }
        val fresh = provider?.let { name ->
            withTimeoutOrNull(20_000) {
                suspendCancellableCoroutine { continuation ->
                    val signal = CancellationSignal()
                    continuation.invokeOnCancellation { signal.cancel() }
                    if (Build.VERSION.SDK_INT >= 30) {
                        manager.getCurrentLocation(name, signal, ContextCompat.getMainExecutor(context)) { continuation.resume(it) }
                    } else {
                        @Suppress("DEPRECATION")
                        manager.requestSingleUpdate(name, { continuation.resume(it) }, context.mainLooper)
                    }
                }
            }
        }
        return fresh ?: providers.mapNotNull { runCatching { manager.getLastKnownLocation(it) }.getOrNull() }
            .maxByOrNull { it.time }
    }

    private fun fusedProvider(): String? = if (Build.VERSION.SDK_INT >= 31) LocationManager.FUSED_PROVIDER else null

    /** "Vancouver, WA": locality (or county) and the region code, like the iOS placemark. */
    private fun placeName(latitude: Double, longitude: Double): String? {
        if (!Geocoder.isPresent()) return null
        return runCatching {
            @Suppress("DEPRECATION")
            val address = Geocoder(context).getFromLocation(latitude, longitude, 1)?.firstOrNull() ?: return null
            val region = address.adminArea?.let { regionCode(it, address.countryCode) }
            listOfNotNull(address.locality ?: address.subAdminArea, region).joinToString(", ").ifEmpty { null }
        }.getOrNull()
    }

    private fun regionCode(adminArea: String, country: String?): String =
        if (country == "US") US_STATES[adminArea] ?: adminArea else adminArea

    private companion object {
        const val ASKED = "sunset.location.asked"
        val US_STATES = mapOf(
            "Alabama" to "AL", "Alaska" to "AK", "Arizona" to "AZ", "Arkansas" to "AR", "California" to "CA",
            "Colorado" to "CO", "Connecticut" to "CT", "Delaware" to "DE", "Florida" to "FL", "Georgia" to "GA",
            "Hawaii" to "HI", "Idaho" to "ID", "Illinois" to "IL", "Indiana" to "IN", "Iowa" to "IA", "Kansas" to "KS",
            "Kentucky" to "KY", "Louisiana" to "LA", "Maine" to "ME", "Maryland" to "MD", "Massachusetts" to "MA",
            "Michigan" to "MI", "Minnesota" to "MN", "Mississippi" to "MS", "Missouri" to "MO", "Montana" to "MT",
            "Nebraska" to "NE", "Nevada" to "NV", "New Hampshire" to "NH", "New Jersey" to "NJ", "New Mexico" to "NM",
            "New York" to "NY", "North Carolina" to "NC", "North Dakota" to "ND", "Ohio" to "OH", "Oklahoma" to "OK",
            "Oregon" to "OR", "Pennsylvania" to "PA", "Rhode Island" to "RI", "South Carolina" to "SC",
            "South Dakota" to "SD", "Tennessee" to "TN", "Texas" to "TX", "Utah" to "UT", "Vermont" to "VT",
            "Virginia" to "VA", "Washington" to "WA", "West Virginia" to "WV", "Wisconsin" to "WI", "Wyoming" to "WY",
            "District of Columbia" to "DC",
        )
    }
}
