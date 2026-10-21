package com.jackwallner.sunset

import android.content.Intent
import com.jackwallner.sunset.data.PackageKind
import com.jackwallner.sunset.data.PeriodUnit
import com.jackwallner.sunset.data.Plan
import com.jackwallner.sunset.data.PlanPeriod
import com.jackwallner.sunset.data.SubscriptionService
import com.jackwallner.sunset.model.DemoForecast

/**
 * Debug-only launch extras, the Android side of the iOS launch arguments.
 * None of this is compiled into a release or QA build.
 *
 *     adb shell am start -n com.jackwallner.sunset/.MainActivity \
 *         --ez demoLocation true --ez demoForecast true --es tab outlook
 *
 * `demoLocation` (Vancouver, WA, skips onboarding), `demoForecast` (fixed
 * week with sky events), `demoPro`, `previewStore` (the iOS prices with
 * no store behind them), `previewTrialUsed`, `onboardingStep <n>`,
 * `tab today|outlook|settings`, `screen detail|events|alerts|paywall`,
 * `uiTest`, `resetAll`, `opens <n>`.
 */
object DebugLaunchOptions {
    var demoLocation = false
        private set
    var screen: String? = null
        private set
    var onboardingStep: Int? = null
        private set

    fun apply(graph: AppGraph, intent: Intent?) {
        val extras = intent?.extras ?: return
        if (extras.getBoolean("resetAll")) graph.defaults.keys().forEach(graph.defaults::remove)
        val automation = extras.getBoolean("uiTest") || extras.containsKey("screen") || extras.containsKey("tab") ||
            extras.containsKey("onboardingStep")
        if (automation) graph.isAutomationRun = true
        if (extras.getBoolean("demoPro")) graph.subscriptions.setLocalOverride(true)
        if (extras.getBoolean("previewStore")) {
            graph.subscriptions.loadPreviewPlans(previewPlans(), trialUsed = extras.getBoolean("previewTrialUsed"))
        }
        if (extras.getBoolean("demoForecast")) graph.forecastStore.pin(DemoForecast.make())
        if (extras.getBoolean("demoLocation")) {
            demoLocation = true
            graph.settings.updateHasOnboarded(true)
            graph.location.useDemoLocation()
        }
        if (extras.containsKey("opens")) repeat(extras.getInt("opens")) { graph.settings.recordOpen() }
        if (extras.containsKey("onboardingStep")) {
            onboardingStep = extras.getInt("onboardingStep")
            graph.settings.updateHasOnboarded(false)
        }
        when (extras.getString("tab")) {
            "outlook" -> graph.navigator.tab = 1
            "settings" -> graph.navigator.tab = 2
        }
        screen = extras.getString("screen")
        if (screen == "paywall") graph.navigator.push(Overlay.Paywall("snapshot"))
        if (screen == "alerts") {
            graph.settings.updateAlertsEnabled(true)
            graph.navigator.push(Overlay.AlertSetup)
        }
        if (screen == "detail") graph.nextShow?.let { graph.navigator.push(Overlay.ShowDetail(it)) }
    }

    /** `Sunset.storekit`: $1.99 monthly and $14.99 yearly with a 1-week trial, $29.99 lifetime. */
    private fun previewPlans(): List<Plan> {
        val trial = PlanPeriod(1, PeriodUnit.WEEK)
        return listOf(
            Plan("\$rc_lifetime", SubscriptionService.LIFETIME, PackageKind.LIFETIME, 29_990_000, "$29.99", "USD", null, null, "Sun+ Lifetime"),
            Plan("\$rc_annual", SubscriptionService.YEARLY, PackageKind.YEARLY, 14_990_000, "$14.99", "USD", PlanPeriod(1, PeriodUnit.YEAR), trial, "Sun+ Yearly"),
            Plan("\$rc_monthly", SubscriptionService.MONTHLY, PackageKind.MONTHLY, 1_990_000, "$1.99", "USD", PlanPeriod(1, PeriodUnit.MONTH), trial, "Sun+ Monthly"),
        )
    }
}
