package com.jackwallner.sunset.data

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.jackwallner.sunset.model.SkyEvent
import com.jackwallner.sunset.model.SunEvent

/**
 * What the user watches and wants to be told about, under the iOS keys.
 * [onAlertsChanged] rebuilds every pending alert; [onWatchedChanged] also
 * refreshes the widget.
 */
class AlertSettings(private val defaults: KeyValueStore, private val cache: ForecastCache) {
    var onAlertsChanged: () -> Unit = {}
    var onWatchedChanged: () -> Unit = {}

    /** Sunrise, sunset, or both. Never empty. */
    var watched by mutableStateOf(cache.watchedEvents)
        private set

    /** Free: an alert before every watched sunrise or sunset that clears the threshold. */
    var alertsEnabled by mutableStateOf(defaults.getBoolean(ENABLED))
        private set

    /** Only shows scoring at or above this alert. Sun+ to change. */
    var threshold by mutableStateOf(defaults.getInt(THRESHOLD).takeIf { it != 0 } ?: DEFAULT_THRESHOLD)
        private set

    /** Minutes before sunset to alert. Sun+ to change. */
    var leadMinutes by mutableStateOf(defaults.getInt(LEAD).takeIf { it != 0 } ?: DEFAULT_LEAD)
        private set

    /** Sun+: which sky events alert. All on by default. */
    var skyEventKinds by mutableStateOf(
        if (defaults.contains(SKY_EVENTS)) defaults.getStringSet(SKY_EVENTS).mapNotNull(SkyEvent.Kind::from).toSet()
        else SkyEvent.Kind.entries.toSet(),
    )
        private set

    var hasOnboarded by mutableStateOf(defaults.getBoolean(ONBOARDED))
        private set

    val openCount: Int get() = defaults.getInt(OPENS)

    fun toggle(event: SunEvent) {
        val next = if (event in watched) watched - event else watched + event
        if (next.isEmpty() || next == watched) return
        watched = next
        cache.watchedEvents = next
        onWatchedChanged()
        onAlertsChanged()
    }

    fun updateAlertsEnabled(value: Boolean) {
        if (value == alertsEnabled) return
        alertsEnabled = value
        defaults.putBoolean(ENABLED, value)
        onAlertsChanged()
    }

    fun updateThreshold(value: Int) {
        if (value == threshold) return
        threshold = value
        defaults.putInt(THRESHOLD, value)
        onAlertsChanged()
    }

    fun updateLeadMinutes(value: Int) {
        if (value == leadMinutes) return
        leadMinutes = value
        defaults.putInt(LEAD, value)
        onAlertsChanged()
    }

    /** Turning a sky event on also turns alerts on, as on iOS. */
    fun setSkyEvent(kind: SkyEvent.Kind, on: Boolean) {
        skyEventKinds = if (on) skyEventKinds + kind else skyEventKinds - kind
        defaults.putStringSet(SKY_EVENTS, skyEventKinds.map { it.raw }.toSet())
        if (on && !alertsEnabled) updateAlertsEnabled(true) else onAlertsChanged()
    }

    fun updateHasOnboarded(value: Boolean) {
        hasOnboarded = value
        defaults.putBoolean(ONBOARDED, value)
    }

    /** The values alerts actually use: free accounts always get the defaults. */
    fun effectiveThreshold(isPro: Boolean) = if (isPro) threshold else DEFAULT_THRESHOLD
    fun effectiveLead(isPro: Boolean) = if (isPro) leadMinutes else DEFAULT_LEAD
    fun effectiveSkyEvents(isPro: Boolean) = if (isPro) skyEventKinds else emptySet()

    fun recordOpen() = defaults.putInt(OPENS, openCount + 1)

    /** The third open while looking at a show worth seeing is the moment to ask, once. */
    fun shouldRequestReview(score: Int): Boolean {
        if (defaults.getBoolean(REVIEW_ASKED) || openCount < 3 || score < 60) return false
        defaults.putBoolean(REVIEW_ASKED, true)
        return true
    }

    companion object {
        val THRESHOLDS = listOf(50, 60, 70, 80, 90)
        val LEAD_OPTIONS = listOf(30, 45, 60, 90, 120)
        const val DEFAULT_THRESHOLD = 70
        const val DEFAULT_LEAD = 45

        private const val ENABLED = "sunset.alerts.enabled"
        private const val THRESHOLD = "sunset.alerts.threshold"
        private const val LEAD = "sunset.alerts.lead"
        private const val SKY_EVENTS = "sunset.alerts.skyEvents"
        private const val ONBOARDED = "sunset.onboarded"
        private const val OPENS = "sunset.opens"
        private const val REVIEW_ASKED = "sunset.reviewAsked"
    }
}
