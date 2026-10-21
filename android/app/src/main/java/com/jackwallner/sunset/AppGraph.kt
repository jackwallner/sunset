package com.jackwallner.sunset

import android.app.Application
import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.setValue
import com.jackwallner.sunset.data.AlertScheduler
import com.jackwallner.sunset.data.AlertSettings
import com.jackwallner.sunset.data.ForecastCache
import com.jackwallner.sunset.data.ForecastStore
import com.jackwallner.sunset.data.LocationService
import com.jackwallner.sunset.data.SharedPreferencesStore
import com.jackwallner.sunset.data.SubscriptionService
import com.jackwallner.sunset.model.SunShow
import com.jackwallner.sunset.widget.SunsetWidget
import kotlinx.coroutines.MainScope

class SunsetApplication : Application() {
    lateinit var graph: AppGraph
        private set

    override fun onCreate() {
        super.onCreate()
        graph = AppGraph(this)
        AlertScheduler.ensureChannel(this)
    }
}

/** Every long-lived object the screens, widget and workers share, built once per process. */
class AppGraph(context: Context) {
    val appContext: Context = context.applicationContext
    val scope = MainScope()
    val defaults = SharedPreferencesStore(appContext)
    val cache = ForecastCache(defaults)
    val settings = AlertSettings(defaults, cache)
    val alerts = AlertScheduler(appContext, defaults)
    val subscriptions = SubscriptionService(appContext, defaults, cache)
    val forecastStore = ForecastStore(cache, scope)
    val location = LocationService(appContext, cache, defaults, scope)
    val navigator = Navigator()

    /** Set by debug launch options for store captures: keeps the review card out of them. */
    var isAutomationRun = false

    init {
        settings.onAlertsChanged = ::rescheduleAlerts
        settings.onWatchedChanged = ::updateWidget
        subscriptions.onProChanged = {
            rescheduleAlerts()
            updateWidget()
        }
        forecastStore.onFetched = {
            updateWidget()
            rescheduleAlerts()
        }
    }

    val nextShow: SunShow? get() = forecastStore.nextShow(settings.watched)

    fun rescheduleAlerts() = alerts.reschedule(forecastStore.forecast, settings, subscriptions.isPro)

    fun updateWidget() = SunsetWidget.updateAll(appContext)

    /** Refreshes the forecast for the latest fix, if there is one. */
    fun refreshForecast(force: Boolean = false) {
        location.location?.let { forecastStore.refresh(it, force) }
    }
}

/** What sits over the tabs, top of the stack last: the iOS pushes and sheets. */
sealed interface Overlay {
    data class ShowDetail(val show: SunShow) : Overlay
    data object AlertSetup : Overlay
    data class Paywall(val source: String) : Overlay
}

class Navigator {
    var tab by mutableIntStateOf(0)
    val overlays = mutableStateListOf<Overlay>()

    val top: Overlay? get() = overlays.lastOrNull()

    fun push(overlay: Overlay) {
        if (top != overlay) overlays.add(overlay)
    }

    fun pop() {
        if (overlays.isNotEmpty()) overlays.removeAt(overlays.lastIndex)
    }

    fun remove(overlay: Overlay) {
        overlays.remove(overlay)
    }
}
